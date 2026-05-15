# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized graduated notifications search", :js, type: :system do
  let(:earliest_time) { Time.current - 2.years }
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[graduated_notifications], graduated_notification_interval: 1.year.to_i, created_at: earliest_time) }
  let(:user) { FactoryBot.create(:organization_admin, organization:) }
  let(:graduated_notifications_path) { "/o/#{organization.to_param}/graduated_notifications" }

  let(:bike1) { FactoryBot.create(:bike_organized, :with_ownership, creation_organization: organization, owner_email: "alice@example.com", created_at: earliest_time) }
  let(:bike2) { FactoryBot.create(:bike_organized, :with_ownership, creation_organization: organization, owner_email: "bob@example.com", created_at: earliest_time) }
  let!(:graduated_notification1) { FactoryBot.create(:graduated_notification_bike_graduated, organization:, bike: bike1) }
  let!(:graduated_notification2) { FactoryBot.create(:graduated_notification_bike_graduated, organization:, bike: bike2) }

  before do
    # Ensure gear types exist so the bike show page doesn't write during readonly mode
    RearGearType.fixed
    FrontGearType.fixed
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
  end

  it "searches by email via turbo, then opens the notification" do
    visit graduated_notifications_path
    # Results load via turbo auto-submit
    expect(page).to have_css("turbo-frame#graduated_notifications_results_frame table.ui-table", wait: 10)
    expect(page).to have_css("tbody tr", count: 2)
    expect(page).to have_css(".select2-container", count: 1, wait: 10)

    # search_no_js should NOT be in the URL (removed by JS controller)
    expect(page).not_to have_current_path(/search_no_js/)

    # The 🔎 emoji next to each email re-filters the table by that email
    within("tbody tr", text: "alice@example.com") { click_link "🔎" }

    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("tbody tr", count: 1)
    expect(page).to have_field("search_email", with: "alice@example.com")
    expect(page).to have_css(".select2-container", count: 1, wait: 10)
    expect(page).to have_content("alice@example.com")
    expect(page).not_to have_content("bob@example.com")

    # Back navigation restores the unfiltered listing
    page.go_back
    expect(page).to have_css("turbo-frame#graduated_notifications_results_frame table.ui-table", wait: 10)
    expect(page).to have_css("tbody tr", count: 2)
    expect(page).to have_field("search_email", with: "")
    expect(page).not_to have_current_path(/search_email=alice/)
    # Verify select2 is re-initialized cleanly: exactly one container AND it opens
    # when clicked (catches turbo-cache stale-DOM regression)
    expect(page).to have_css(".select2-container", count: 1, wait: 10)
    find(".select2-container").click
    expect(page).to have_css(".select2-container--open", wait: 5)
    # Close it again so subsequent interactions aren't blocked by the dropdown
    find("body").send_keys(:escape)

    # Search by email via the form, then press back directly. Regression guard
    # for the turbo:submit-start spinner-replacement: showLoadingSpinnerAndDisableButton
    # replaces the frame's innerHTML with the spinner before Turbo snapshots the
    # previous URL. Without a fix, back-nav restores that broken snapshot —
    # form still has "alice", URL has no query, frame stuck on the spinner.
    fill_in "search_email", with: "alice@example.com"
    find("#search-button").click

    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("tbody tr", count: 1)
    expect(page).to have_content("alice@example.com")
    expect(page).not_to have_content("bob@example.com")
    # turbo-frame element must survive the turbo_stream response (regression guard:
    # turbo_stream.replace would remove the frame element, breaking subsequent submits
    # and back-nav restoration)
    expect(page).to have_css("turbo-frame#graduated_notifications_results_frame")

    page.go_back
    expect(page).not_to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("turbo-frame#graduated_notifications_results_frame table.ui-table", wait: 10)
    expect(page).to have_css("tbody tr", count: 2)
    expect(page).to have_field("search_email", with: "")

    # Re-apply the alice filter so the next steps (click row, back-nav) have state
    fill_in "search_email", with: "alice@example.com"
    find("#search-button").click

    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("tbody tr", count: 1)

    within("tbody tr") { first("a.preciseTime").click }

    expect(page).to have_current_path(%r{/o/\S+/graduated_notifications/#{graduated_notification1.id}\z}, wait: 10)
    expect(page).to have_css("h1", text: "Graduated notification")
    expect(page).to have_content("alice@example.com")
    expect(page).to have_content("User Bikes")

    # Going back restores the filtered search: URL, populated field, and single-row table
    page.go_back
    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("turbo-frame#graduated_notifications_results_frame table.ui-table", wait: 10)
    expect(page).to have_css("tbody tr", count: 1)
    expect(page).to have_field("search_email", with: "alice@example.com")
    expect(page).to have_content("alice@example.com")
    expect(page).not_to have_content("bob@example.com")
    # select2-powered combobox is re-initialized exactly once (no double-init, no missing init)
    expect(page).to have_css(".select2-container", count: 1, wait: 10)

    within("tbody tr") { find("a[href^='/bikes/']").click }

    expect(page).to have_current_path(%r{/bikes/#{bike1.id}(\?|\z)}, wait: 10)
    expect(page).to have_css(".organized-access-panel")

    # Going back from the bike show page also restores the filtered search
    page.go_back
    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("turbo-frame#graduated_notifications_results_frame table.ui-table", wait: 10)
    expect(page).to have_css("tbody tr", count: 1)
    expect(page).to have_field("search_email", with: "alice@example.com")
    expect(page).to have_content("alice@example.com")
    expect(page).not_to have_content("bob@example.com")
    expect(page).to have_css(".select2-container", count: 1, wait: 10)
  end
end
