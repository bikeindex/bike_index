# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reporting a registration stolen, then recovered", :js, type: :system do
  let(:owner) { FactoryBot.create(:user_confirmed, name: "Owner McOwnerface") }
  let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: owner) }
  let!(:united_states) { Country.united_states }

  # Picks an option from a selectize-enhanced control found within the given scope
  def pick_within_selectize(control, text)
    control.find(".selectize-input").click
    control.find(".selectize-dropdown-content .option", text:, wait: 5).click
  end

  def selectize_for(css)
    find(css, visible: :all).find(:xpath, "./following-sibling::div[contains(@class, 'selectize-control')][1]")
  end

  def save_bike
    find(".edit-form-well-submit-wrapper input[type=submit]").click
    expect(page).to have_content("Bike successfully updated!", wait: 10)
  end

  # Delay the recovery request so the flow has to wait for it to complete rather
  # than navigating away before the bike is recovered. Reproduces the real-world
  # latency a user hits; without it a fast local request masks the bug.
  def delay_recovery_request(seconds)
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.route("**/api/v1/users/send_request", ->(route, _request) {
        sleep seconds
        route.continue
      })
    end
  end

  it "reports the bike stolen with theft details, then marks it recovered" do
    # Sign in
    visit new_session_path
    fill_in "Email", with: owner.email
    click_button "Continue"
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
    expect(page).to have_content("Logged in", wait: 5)

    dismiss_donation_modal

    # ---- Report the bike stolen ----
    expect(bike.status_stolen?).to be_falsey
    visit edit_bike_path(bike, edit_template: "report_stolen")
    click_button "This bike is stolen or missing!"

    # Reporting stolen redirects to the theft details form and opens the promoted
    # theft-alert upsell modal; dismiss it before filling the form
    expect(page).to have_css("#tryAPromotedAlert.in", wait: 10)
    find("#tryAPromotedAlert .close").click
    expect(page).to have_no_css("#tryAPromotedAlert.in", wait: 5)

    expect(bike.reload.status_stolen?).to be_truthy

    # ---- Fill the required theft details (country, street, city) plus useful extras ----
    pick_within_selectize(selectize_for("select.country-select-input"), "United States")
    fill_in "Address or intersection", with: "100 Main St"
    fill_in "City", with: "New York"
    fill_in "Postal code", with: "10001"
    fill_in "Phone", with: "3125551234"
    fill_in "Description of the incident", with: "Cut lock outside the cafe"
    save_bike

    stolen_record = bike.reload.current_stolen_record
    expect(stolen_record).to be_present
    expect(stolen_record.country_id).to eq united_states.id
    expect(stolen_record.street).to eq "100 Main St"
    expect(stolen_record.city).to eq "New York"
    expect(stolen_record.postal_code).to eq "10001"
    expect(stolen_record.phone).to eq "3125551234"
    expect(stolen_record.theft_description).to eq "Cut lock outside the cafe"
    expect(stolen_record.date_stolen).to be_present

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
    delay_recovery_request(2)

    visit edit_bike_path(bike, edit_template: "report_recovered")
    find("[data-target='#toggle-stolen']").click

    within("#toggle-stolen") do
      expect(page).to have_css(".modal-body", visible: true, wait: 5)
      fill_in "mark_recovered_reason", with: "Found it locked up around the corner"
      click_button "Mark recovered"
    end

    # While the (delayed) recovery request is in flight, the spinner is shown
    expect(page).to have_content("Marking your bike recovered", wait: 5)

    # After recovery the bike is no longer stolen: the theft nav is gone and the
    # "Report Stolen or Missing" nav (only shown for un-stolen bikes) appears
    expect(page).to have_link("Report Stolen or Missing", wait: 10)
    expect(page).to have_no_link("Mark this Bike Recovered")

    stolen_record.reload
    expect(stolen_record.recovered?).to be_truthy
    expect(stolen_record.recovered_description).to eq "Found it locked up around the corner"

    bike.reload
    expect(bike.status_stolen?).to be_falsey
    expect(bike.current_stolen_record_id).to be_blank
  end
end
