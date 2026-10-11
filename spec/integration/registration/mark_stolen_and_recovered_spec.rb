# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reporting a registration stolen, then recovered", :js, type: :system do
  let(:owner) { FactoryBot.create(:user_confirmed, name: "Owner McOwnerface") }
  let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: owner) }
  let!(:united_states) { Country.united_states }
  # The photo step searches Bike Book for a stock photo
  before { stub_bikebook_catalog }

  it "reports the bike stolen with theft details, then marks it recovered" do
    sign_in(owner)
    expect(page).to have_content("Logged in")

    dismiss_donation_modal

    # ---- Report the bike stolen, through the wizard ----
    expect(bike.status_stolen?).to be_falsey
    visit edit_bike_path(bike, edit_template: "report_stolen")
    expect(page).to have_content("When and where was it stolen?")
    expect(page).to have_content("Step 1 of 7")

    # Required answers hold the step until they're given
    click_button "Continue"
    expect(page).to have_content("Required so we can alert people nearby")
    expect(page).to have_content("When and where was it stolen?")

    fill_in "Date", with: "2026-10-10"
    fill_in "Address or intersection", with: "100 Main St"
    fill_in "City", with: "New York"
    fill_in "Postal code", with: "10001"
    expect(page).to have_no_content("Required so we can alert people nearby")
    click_button "Continue"

    expect(page).to have_content("How was it locked?")
    find("label", text: "U-lock and cable").click
    find("label", text: "Lock was cut, and left at the scene").click
    fill_in "What happened?", with: "Cut lock outside the cafe"
    click_button "Continue"

    # The optional steps can be skipped, and the rail says so
    expect(page).to have_content("Photos of your bike")
    click_button "Skip for now"
    expect(page).to have_content("Police report")
    click_button "Skip for now"
    expect(page).to have_content("How can people reach you?")
    fill_in "Phone", with: "3125551234"
    click_button "Continue"
    expect(page).to have_content("Value and proof of ownership")
    click_button "Skip for now"

    expect(page).to have_content("Review your report")
    expect(page).to have_content("Skipped · add later")
    expect(page).to have_content("100 Main St, New York, 10001")
    expect(page).to have_content("U-lock and cable · Lock was cut, and left at the scene")
    click_button "Report as stolen"

    expect(page).to have_content("Your bike is now marked STOLEN.", wait: 10)
    expect(page).to have_content("Add your police report number")
    expect(page).to have_link("Add report")

    stolen_record = bike.reload.current_stolen_record
    expect(bike.status_stolen?).to be_truthy
    expect(stolen_record.country_id).to eq united_states.id
    expect(stolen_record.street).to eq "100 Main St"
    expect(stolen_record.city).to eq "New York"
    expect(stolen_record.postal_code).to eq "10001"
    expect(stolen_record.phone).to eq "3125551234"
    expect(stolen_record.locking_description).to eq "U-lock and cable"
    expect(stolen_record.theft_description).to eq "Cut lock outside the cafe"
    # Midnight in the browser's zone, which the app's can put on another day
    expect(stolen_record.date_stolen).to be_within(1.day).of Time.zone.parse("2026-10-10")

    # The checklist's links reopen the wizard on their step
    click_link "Add report"
    expect(page).to have_content("Step 4 of 7")
    fill_in "Report number", with: "2026-1234"
    fill_in "Department & city", with: "NYPD"
    click_button "Continue"
    click_button "Continue"
    click_button "Skip for now"
    click_button "Save changes"
    expect(page).to have_content("Police report added", wait: 10)
    expect(stolen_record.reload.police_report_number).to eq "2026-1234"

    # ---- Send a message through the stolen bike's contact-owner form. The owner
    # doesn't see that card (they don't contact themselves), so view the public
    # perspective. The form is fragment-cached (Pages::Registrations::Show::Wrapper), so its
    # session-scoped CSRF token is reissued client-side by the csrf-refresh controller.
    # The stale-token failure itself can't be reproduced here (it needs production
    # fragment caching + forgery protection, both off in test), so this exercises the
    # form end-to-end; the component spec guards the csrf-refresh hook. ----
    RearGearType.fixed # bike-details render creates this lazily, which is read-only mid-request
    visit registration_path(bike, view_as: "public")
    within("[data-controller~='ui--collapse']") do
      click_on "Contact the owner"
      fill_in "stolen_notification[message]", with: "Saw this locked up outside the library"
      click_on "Send message"
    end
    expect(page).to have_content("Thanks for looking out!", wait: 10)

    # ---- Mark the bike recovered ----
    visit edit_bike_path(bike, edit_template: "report_recovered")
    expect(page).to have_content("We're so glad you got your bike back!")
    find("label", text: "Found it myself").click
    click_button "Mark as recovered"
    expect(page).to have_content("A sentence or two is plenty")

    fill_in "Tell us the story", with: "Found it locked up around the corner"
    click_button "Mark as recovered"
    expect(page).to have_content("Welcome home", wait: 10)
    expect(page).to have_content("Ways to support Bike Index")

    stolen_record.reload
    expect(stolen_record.recovered?).to be_truthy
    expect(stolen_record.recovered_description).to eq "Found it myself: Found it locked up around the corner"
    expect(stolen_record.can_share_recovery).to be_truthy

    bike.reload
    expect(bike.status_stolen?).to be_falsey
    expect(bike.current_stolen_record_id).to be_blank
  end
end
