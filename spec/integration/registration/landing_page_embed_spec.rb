# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organization landing page registration embed", :js, type: :system do
  let(:owner_email) { "owner@bikeindex.org" }
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Surly") }
  # The slug LandingPageOrganizations::SLUGS routes by default, so /brakebills is the landing page
  let!(:organization) { FactoryBot.create(:organization, name: "Brakebills") }
  let!(:organization_landing_page) { FactoryBot.create(:organization_landing_page, organization:, body:) }
  # The column the seeded page frames it in, which is narrower than the combobox's
  # mobile breakpoint
  let(:body) do
    <<~HTML
      <h1>Brakebills University Bicycle Registration</h1>
      <div class="container"><div class="row"><div class="col-md-5">
        <iframe src="/register/embed?organization_id=brakebills&button=c9a227"
          title="Register your bike with Brakebills University"
          style="width: 100%; border: none; height: 620px;"></iframe>
      </div></div></div>
    HTML
  end

  before do
    # The manufacturer combobox autocompletes against the redis index
    Autocomplete::Loader.clear_redis
    Autocomplete::Loader.load_all(%w[Manufacturer])
  end

  it "starts the registration in the frame and leaves it for step 2" do
    visit "/brakebills"
    expect(page).to have_content("Brakebills University Bicycle Registration")

    within_frame(find("iframe")) do
      # The page around the frame names the organization, so the heading doesn't
      expect(page).to have_content("Register your vehicle!")
      expect(page).to have_no_css("nav.primary-header-nav")
      # Matches the page it's framed on
      expect(page).to have_css("button[type=submit][style*='#c9a227']")

      type_into("#b_param_manufacturer_id", "Surly")
      # The frame is under the combobox's mobile breakpoint but the screen isn't, so it
      # drops down inline rather than opening the picker meant for a phone
      expect(page).to have_css(".hw-combobox__option", text: "Surly")
      expect(page).to have_no_css(".hw-combobox__dialog__listbox")
      click_combobox_option("Surly")
      fill_in "b_param[owner_email]", with: owner_email
      click_button "Next"
    end

    # The whole page moved on, rather than step 2 rendering inside the frame
    expect(page).to have_content("Add your bike", wait: 10)
    expect(page).to have_current_path(/register\?b_param_token=.+&step=2/, url: true)
    expect(page).to have_css("nav.primary-header-nav")

    expect(BParam.last).to have_attributes(owner_email:, manufacturer_id: manufacturer.id,
      creation_organization_id: organization.id)
  end

  it "opens the combobox picker in the frame on a phone, where the screen is small" do
    resize_window(width: 390, height: 844)
    visit "/brakebills"

    within_frame(find("iframe")) do
      type_into("#b_param_manufacturer_id", "Surly")
      expect(page).to have_css(".hw-combobox__dialog__listbox")
    end
  end
end
