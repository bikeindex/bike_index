# frozen_string_literal: true

require "rails_helper"

# Without the :js tag these run on the rack_test driver, which never executes
# JavaScript - so the steps post as plain forms (the `data-turbo` they carry is
# inert), and register--retry, the submit spinners and the comboboxes never wire
# up. A combobox submits through a hidden field only its Stimulus controller
# writes, so each one the flow needs is backed by a UI::Forms::NoJsText textbox
# that only exists when scripting is off.
RSpec.describe "Register flow without JavaScript", type: :system do
  let(:owner_email) { "owner@bikeindex.org" }
  let(:user_name) { "Sally Rider" }
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Surly") }
  let!(:red) { FactoryBot.create(:color, name: "Red") }

  # type: :system defaults to the selenium driver; force rack_test so no
  # JavaScript runs at all
  before { driven_by(:rack_test) }

  it "registers a bike through the textboxes the comboboxes fall back to" do
    visit "/register/new"

    # Starting the registration and landing on its tokenized step 1 is all redirects,
    # so it works the same either way
    expect(page).to have_current_path(/register\?b_param_token=.+&step=1/, url: true)
    expect(page).to have_content("Register your bike!")

    # The combobox is inside the wrapper the layout's noscript stylesheet hides, and
    # the field carrying its name is the textbox standing in for it
    expect(page).to have_css("[data-js-required] input#b_param_manufacturer_id")
    expect(page).to have_css("noscript input[name='b_param[manufacturer_id]']", visible: :all)

    fill_in "b_param[manufacturer_id]", with: "Surly"
    fill_in "b_param[owner_email]", with: owner_email
    click_button "Next"

    # A name where the combobox would have put an id - the server resolves either
    expect(page).to have_content("Add your bike")
    expect(BParam.last.manufacturer_id).to eq manufacturer.id

    fill_in "bike[user_name]", with: user_name
    fill_in "bike[primary_frame_color]", with: "Red"
    fill_in "bike[serial_number]", with: "XYZ 123"
    click_button "Complete Bike Registration"

    # Anonymous, so there's nobody to own a bike yet - it's held for the emailed link
    expect(page).to have_content("Registration saved")
    expect(page).to have_content("verify your email")
    expect(Bike.count).to eq 0

    # The link is a GET onto a plain one-button form, which is a form either way
    visit confirmation_link
    expect(page).to have_content("Confirming your email")
    click_button "Continue"

    expect(page).to have_content("Registration complete")
    # Every one of these came from a textbox that only exists without JavaScript
    expect(Bike.last).to have_attributes(owner_email:, serial_number: "XYZ 123",
      manufacturer_id: manufacturer.id, primary_frame_color_id: red.id)
  end

  it "keeps a manufacturer it doesn't know as free text, and takes a typed cycle type" do
    visit "/register/new"

    # The datalist suggests what the combobox would have listed, without needing it open
    expect(page).to have_css("noscript datalist option[value='e-scooter']", visible: :all)

    fill_in "b_param[manufacturer_id]", with: "Fabriquer Cycles"
    fill_in "b_param[cycle_type]", with: "e-scooter"
    fill_in "b_param[owner_email]", with: owner_email
    click_button "Next"

    expect(page).to have_content("Add your")
    b_param = BParam.last
    # Unrecognized, so it lands the way the combobox's own free text does
    expect(b_param.manufacturer_id).to eq Manufacturer.other.id
    expect(b_param.manufacturer_other).to eq "Fabriquer Cycles"
    expect(b_param.cycle_type).to eq "e-scooter"
  end

  # The safety pages gate their submit behind every box being checked, which without
  # JavaScript can only be the server's job - so the button ships enabled
  context "an organization's e-vehicle safety rules" do
    let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
    # Built as a draft and activated below, since activation freezes the pages
    let(:sequence) do
      FactoryBot.create(:registration_sequence, organization:,
        acknowledgment_text: "agree to comply with all of the rules above.")
    end
    let!(:campus_page) do
      FactoryBot.create(:registration_sequence_page, registration_sequence: sequence,
        title: "Campus rules", body: "<ul><li>Dismount in posted zones</li></ul>",
        organization_specific: true)
    end

    before { sequence.make_active! }

    it "walks the rules and signs the acknowledgment" do
      visit "/register/new?organization_id=#{organization.slug}"

      fill_in "b_param[manufacturer_id]", with: "Surly"
      fill_in "b_param[cycle_type]", with: "e-scooter"
      fill_in "b_param[owner_email]", with: owner_email
      click_button "Next"

      fill_in "bike[user_name]", with: user_name
      fill_in "bike[primary_frame_color]", with: "Red"
      fill_in "bike[serial_number]", with: "XYZ 123"
      click_button "Next"

      expect(page).to have_content("Campus rules")
      # The server is what holds the gate, so agreeing to nothing gets turned away
      click_button "Continue"
      expect(page).to have_content("Campus rules")

      check "Dismount in posted zones"
      click_button "Continue"

      expect(page).to have_content("You're almost done")
      check "I, #{user_name}, agree to comply with all of the rules above."
      click_button "Complete e-Scooter Registration"

      expect(page).to have_content("Registration saved")
      expect(RegistrationSequenceAcknowledgment.count).to eq 1
    end
  end

  it "says what's missing when a required textbox is left empty" do
    visit "/register/new"
    fill_in "b_param[owner_email]", with: owner_email
    click_button "Next"

    # Nothing silently swallowed - the step re-renders with what was entered
    expect(page).to have_content("Manufacturer is required to register")
    expect(page).to have_field("b_param[owner_email]", with: owner_email)
    expect(page.status_code).to eq 422
    expect(BParam.last.manufacturer_id).to be_blank
  end
end
