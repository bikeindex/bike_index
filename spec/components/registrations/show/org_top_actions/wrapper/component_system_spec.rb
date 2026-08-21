# frozen_string_literal: true

require "rails_helper"

RSpec.describe Registrations::Show::OrgTopActions::Wrapper::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/registrations/show/org_top_actions/wrapper/component/default" }
  # The preview renders against the seeded brakebills org, so every feature-gated action shows
  let!(:organization) { FactoryBot.create(:organization_brakebills) }

  # The preview stacks a section per scenario, each its own accordion
  def scenario(label)
    find("section", text: label)
  end

  it "opens one panel at a time, keeping the open panel in the URL" do
    visit preview_path

    owner_section = scenario("With owner")

    within(owner_section) do
      expect(page).to have_button("Message Owner")
      expect(page).to have_button("New Parking Notification")
      # Panels start closed
      expect(page).to have_no_button("Send message")

      click_button "Message Owner"

      expect(page).to have_button("Send message")
      expect(page).to have_css("button[data-active='true']", text: "Message Owner")
    end

    expect(page).to have_current_path(/panel=message/, url: true)
    expect_axe_clean

    within(owner_section) do
      # Opening another panel closes the message panel
      click_button "View Notifications"

      expect(page).to have_content("No parking notifications for this bike")
      expect(page).to have_no_button("Send message")
      expect(page).to have_css("button[data-active='false']", text: "Message Owner")
    end

    expect(page).to have_current_path(/panel=notifications_show/, url: true)

    within(owner_section) do
      # Clicking the open panel's trigger closes it
      click_button "View Notifications"

      expect(page).to have_no_content("No parking notifications for this bike")
    end

    expect(page).to have_no_current_path(/panel=/, url: true)
  end

  context "with a parking notification" do
    let!(:parking_notification) { FactoryBot.create(:parking_notification, organization:) }

    it "renders the notification, through helpers the preview has to supply" do
      visit preview_path

      within(scenario("With parking notification")) { click_button "View Notifications" }

      expect(page).to have_content("Parked incorrectly notification")
      expect(page).to have_content("Notification#")
      expect_axe_clean
    end
  end
end
