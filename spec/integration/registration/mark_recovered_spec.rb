# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Marking a stolen registration recovered", :js, type: :system do
  let(:owner) { FactoryBot.create(:user_confirmed, name: "Owner McOwnerface") }
  let!(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, user: owner) }
  let(:stolen_record) { bike.current_stolen_record }

  before { expect(stolen_record).to be_present }

  # Delay the recovery request so the flow has to wait for it to complete rather
  # than navigating away before the bike is actually recovered. Reproduces the
  # real-world latency a user hits; without it a fast local request masks the bug.
  def delay_recovery_request(seconds)
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.route("**/api/v1/users/send_request", ->(route, _request) {
        sleep seconds
        route.continue
      })
    end
  end

  it "marks the bike recovered and removes the stolen information" do
    # Sign in
    visit new_session_path
    fill_in "Email", with: owner.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
    expect(page).to have_content("Logged in", wait: 5)

    # Dismiss the donation modal that greets logged-in users
    find("#donationModal .close").click
    expect(page).to have_no_css("#donationModal.in", wait: 5)

    delay_recovery_request(2)

    # Open the "Mark this Bike Recovered" edit page and start the recovery flow
    visit edit_bike_path(bike, edit_template: "report_recovered")
    find("[data-target='#toggle-stolen']").click

    within("#toggle-stolen") do
      expect(page).to have_css(".modal-body", visible: true, wait: 5)
      fill_in "mark_recovered_reason", with: "Found it locked up around the corner"
      click_button "Mark recovered"
    end

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
