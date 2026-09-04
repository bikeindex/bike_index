# frozen_string_literal: true

require "rails_helper"

# A real browser with scripting off is the only thing that answers what a rider without
# JavaScript gets: the steps post as plain forms, `<noscript>` becomes real DOM, and - the
# part no other driver reaches - HTML5 constraint validation runs against the stylesheet
# that hides each combobox. Each one falls back to a UI::Forms::NoJsField control.
RSpec.describe "Register flow without JavaScript", type: :system, driver: :playwright_no_js do
  # Only the fixtures are used here - scripting is off, so there are no comboboxes to
  # type into and no controllers to wait for
  include_context :register_flow_steps

  it "registers a bike through the plain controls the comboboxes fall back to" do
    visit "/register/new"

    # All redirects up to here, so it works the same either way
    expect(page).to have_current_path(/register\?b_param_token=.+&step=1/, url: true)
    expect(page).to have_content("Register your vehicle!")

    # Really hidden: the stylesheet ships inside the noscript, so only a browser with
    # scripting off renders it this way
    expect(page).to have_no_css("[data-js-required] input#b_param_manufacturer_id")
    # ...and what stands in for it is usable. A textbox, since manufacturers come from an
    # endpoint and take free text
    expect(page).to have_css("input[name='b_param[manufacturer_id]']")
    # The cycle types are a list worth showing, so that one falls back to a select
    expect(page).to have_select("b_param[cycle_type]")

    fill_in "b_param[manufacturer_id]", with: "Surly"
    fill_in "b_param[owner_email]", with: owner_email
    click_button "Next"

    # A name where the combobox would have put an id - the server resolves either
    expect(page).to have_content("Add your bike")
    expect(BParam.last.manufacturer_id).to eq manufacturer.id

    fill_in "bike[user_name]", with: user_name
    # The select posts the color's own id, so nothing has to resolve a typed name
    select "Red", from: "bike[primary_frame_color_id]"
    fill_in "bike[serial_number]", with: "XYZ 123"
    click_button "Complete Bike Registration"

    # Anonymous, so there's nobody to own a bike yet - it's held for the emailed link
    expect(page).to have_css("h1", text: "Progress saved")
    expect(page).to have_content("verify your email")
    expect(Bike.count).to eq 0

    # The link is a GET onto a plain one-button form, which is a form either way
    visit confirmation_link
    expect(page).to have_content("Confirming your email")
    click_button "Continue"

    expect(page).to have_content("Registration complete")
    # Every one of these came from a control that only exists without JavaScript
    expect(Bike.last).to have_attributes(owner_email:, serial_number: "XYZ 123",
      manufacturer_id: manufacturer.id, primary_frame_color_id: red.id)
  end

  # The report is the one step whose fields are all plain controls already - what it needs
  # from JavaScript is the timezone the wall-clock time was entered in, which it does
  # without by reading the time back in the zone the field rendered in
  it "reports a theft picked from the status fallback" do
    state = FactoryBot.create(:state_new_york)
    visit "/register/new"

    fill_in "b_param[manufacturer_id]", with: "Surly"
    fill_in "b_param[owner_email]", with: owner_email
    click_button "Next"

    fill_in "bike[user_name]", with: user_name
    select "Red", from: "bike[primary_frame_color_id]"
    fill_in "bike[serial_number]", with: "XYZ 123"
    # The status is a combobox too, so which registration this is gets picked here
    select "Stolen", from: "bike[status]"
    click_button "Complete Bike Registration"

    # Anonymous, so the theft waits on the link that proves the address
    expect(page).to have_css("h1", text: "Progress saved")
    expect(page).to have_content("Finish reporting your stolen bike")
    expect(BParam.last.status).to eq "status_stolen"

    visit confirmation_link
    click_button "Continue"

    expect(page).to have_content("Report your stolen bike")
    # Nothing entered for when and where, so the browser holds the step here
    click_button "Complete Bike Registration"
    expect(page).to have_content("Report your stolen bike")
    expect(Bike.count).to eq 0

    fill_in "report[date]", with: "2026-08-05T14:30"
    fill_in "report[address_record_attributes][street]", with: "278 Broadway"
    fill_in "report[address_record_attributes][city]", with: "New York"
    select state.name, from: "report[address_record_attributes][region_record_id]"
    fill_in "report[address_record_attributes][postal_code]", with: "10007"
    fill_in "report[theft_description]", with: "Cut lock"
    click_button "Complete Bike Registration"

    expect(page).to have_css("h1", text: "is listed as stolen on Bike Index")
    stolen_record = Bike.last.current_stolen_record
    expect(stolen_record).to have_attributes(street: "278 Broadway", city: "New York",
      theft_description: "Cut lock")
    # No timezone field to fill it in, so the time reads back in the zone it rendered in
    expect(stolen_record.date_stolen.in_time_zone.strftime("%Y-%m-%dT%H:%M")).to eq "2026-08-05T14:30"
  end

  it "keeps a manufacturer it doesn't know as free text, and takes a chosen cycle type" do
    visit "/register/new"

    # Blank first, so a required select can't submit whichever option sorts first
    expect(page).to have_css("noscript select[name='b_param[cycle_type]'] option[value='']", visible: :all)

    fill_in "b_param[manufacturer_id]", with: "Fabriquer Cycles"
    select "e-Scooter", from: "b_param[cycle_type]"
    fill_in "b_param[owner_email]", with: owner_email
    click_button "Next"

    expect(page).to have_content("Add your")
    b_param = BParam.last
    # Unrecognized, so it lands the way the combobox's own free text does
    expect(b_param.manufacturer_id).to eq Manufacturer.other.id
    expect(b_param.manufacturer_other).to eq "Fabriquer Cycles"
    expect(b_param.cycle_type).to eq "e-scooter"
  end

  # Every box has to be checked, which without JavaScript is the server's job alone -
  # so the button ships enabled
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
      select "e-Scooter", from: "b_param[cycle_type]"
      fill_in "b_param[owner_email]", with: owner_email
      click_button "Next"

      fill_in "bike[user_name]", with: user_name
      select "Red", from: "bike[primary_frame_color_id]"
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

      expect(page).to have_css("h1", text: "Progress saved")
      expect(RegistrationSequenceAcknowledgment.count).to eq 1
    end
  end

  # The browser's own validation is what makes the fallback a control rather than
  # decoration - and what a required combobox hidden behind it would break outright
  it "holds the step until the fallback is filled, then lets it through" do
    visit "/register/new"
    step_1_url = page.current_url

    fill_in "b_param[owner_email]", with: owner_email
    click_button "Next"

    # Nothing entered for the manufacturer, so the browser never posts it
    expect(page).to have_current_path(step_1_url, url: true)
    expect(BParam.last.manufacturer_id).to be_blank

    fill_in "b_param[manufacturer_id]", with: "Surly"
    click_button "Next"

    expect(page).to have_content("Add your bike")
    expect(BParam.last.manufacturer_id).to eq manufacturer.id
  end
end
