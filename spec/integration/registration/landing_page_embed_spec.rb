# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organization landing page registration embed", :js, type: :system do
  let(:owner_email) { "owner@bikeindex.org" }
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Surly") }
  # The slug LandingPages::ORGANIZATIONS routes by default, so /brakebills is the landing page
  let!(:organization) { FactoryBot.create(:organization, name: "Brakebills", landing_html:) }
  let(:landing_html) do
    <<~HTML
      <h1>Brakebills University Bicycle Registration</h1>
      <iframe src="/register/embed?organization_id=brakebills"
        title="Register your bike with Brakebills University"
        style="width: 100%; border: none; height: 620px;"></iframe>
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
      expect(page).to have_content("Register your bike with Brakebills!")
      expect(page).to have_no_css("nav.primary-header-nav")

      type_into("#b_param_manufacturer_id", "Surly")
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
end
