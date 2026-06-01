# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized graduated notifications search", :js, type: :system do
  let(:earliest_time) { Time.current - 2.years }
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[graduated_notifications], graduated_notification_interval: 1.year.to_i, created_at: earliest_time) }
  let(:user) { FactoryBot.create(:organization_admin, organization:) }
  let(:graduated_notifications_path) { "/o/#{organization.to_param}/graduated_notifications" }

  let(:bike1) { FactoryBot.create(:bike_organized, :with_ownership, creation_organization: organization, owner_email: "alice@example.com", created_at: earliest_time) }
  let(:bike2) { FactoryBot.create(:bike_organized, :with_ownership, creation_organization: organization, owner_email: "bob@example.com", created_at: earliest_time) }
  let(:bike3) { FactoryBot.create(:bike_organized, :with_ownership, creation_organization: organization, owner_email: "carol@example.com", created_at: earliest_time) }
  let!(:graduated_notification1) { FactoryBot.create(:graduated_notification_bike_graduated, organization:, bike: bike1) }
  let!(:graduated_notification2) { FactoryBot.create(:graduated_notification_bike_graduated, organization:, bike: bike2) }
  # marked_remaining is excluded from the default "current" status filter
  let!(:graduated_notification3) { FactoryBot.create(:graduated_notification, :marked_remaining, organization:, bike: bike3) }

  before do
    # Ensure gear types exist so the bike show page doesn't write during readonly mode
    RearGearType.fixed
    FrontGearType.fixed
    # Populate autocomplete so the combobox can match "Black"
    Color.black
    Autocomplete::Loader.load_all(%w[Color])
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
    # Dismiss the post-login flash and wait for it to clear, so the next
    # navigation isn't racing the redirect. The Bootstrap fade-out can exceed
    # Capybara's default 2s wait on slow CI runners.
    find(".alert-success .close").click
    expect(page).to have_no_css(".alert-success", wait: 10)
  end

  it "searches by email via turbo, then opens the notification" do
    visit graduated_notifications_path
    # Results load via the eager turbo-frame (src fetched once the frame connects)
    expect(page).to have_css("turbo-frame#graduated_notifications_results_frame table.ui-table", wait: 10)
    expect(page).to have_css("tbody tr", count: 2, wait: 10)
    expect(page).to have_css(".hw-combobox", count: 1, wait: 10)

    # search_no_js should NOT be in the URL (removed by JS controller)
    expect(page).not_to have_current_path(/search_no_js/)

    # The 🔎 emoji next to each email re-filters the table by that email
    within("tbody tr", text: "alice@example.com") { click_link "🔎" }

    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("tbody tr", count: 1, wait: 10)
    expect(page).to have_field("search_email", with: "alice@example.com")
    expect(page).to have_css(".hw-combobox", count: 1, wait: 10)
    expect(page).to have_content("alice@example.com")
    expect(page).not_to have_content("bob@example.com")

    # Back navigation restores the unfiltered listing
    page.go_back
    expect(page).to have_css("turbo-frame#graduated_notifications_results_frame table.ui-table", wait: 10)
    expect(page).to have_css("tbody tr", count: 2, wait: 10)
    expect(page).to have_field("search_email", with: "")
    expect(page).not_to have_current_path(/search_email=alice/)
    # combobox search: type a query, pick the autocomplete option, submit
    # (also catches turbo-cache stale-DOM regression — the combobox must be usable)
    expect(page).to have_css(".hw-combobox", count: 1, wait: 10)
    find(".hw-combobox__input").set("Black")
    expect(page).to have_css(".hw-combobox__option", text: "Black", wait: 10)
    find(".hw-combobox__option", text: "Black", match: :first).click
    find("#search-button").click

    expect(page).to have_current_path(/query_items/, wait: 10)
    expect(page).to have_css("turbo-frame#graduated_notifications_results_frame", wait: 10)

    page.go_back
    # Back navigation restores the default (unfiltered) search. The eager
    # turbo-frame loads results without rewriting the address bar, so the
    # default search sits at the bare path rather than a serialized query.
    expect(page).to have_current_path(graduated_notifications_path, wait: 10)
    expect(page).not_to have_current_path(/query_items/)
    expect(page).to have_css("turbo-frame#graduated_notifications_results_frame table.ui-table", wait: 10)
    expect(page).to have_css("tbody tr", count: 2, wait: 10)
    expect(page).to have_field("search_email", with: "")

    # Form submit + direct back-nav: regression guard for turbo-cache spinner state
    fill_in "search_email", with: "alice@example.com"
    find("#search-button").click

    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("tbody tr", count: 1, wait: 10)
    expect(page).to have_content("alice@example.com")
    expect(page).not_to have_content("bob@example.com")
    # turbo-frame survives the turbo_stream response (catches replace-vs-update regression)
    expect(page).to have_css("turbo-frame#graduated_notifications_results_frame")

    page.go_back
    expect(page).not_to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("turbo-frame#graduated_notifications_results_frame table.ui-table", wait: 10)
    expect(page).to have_css("tbody tr", count: 2, wait: 10)
    expect(page).to have_field("search_email", with: "")

    # Re-apply alice filter for click-row/back-nav steps
    fill_in "search_email", with: "alice@example.com"
    find("#search-button").click

    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("tbody tr", count: 1, wait: 10)

    within("tbody tr") { first("a.preciseTime").click }

    expect(page).to have_current_path(%r{/o/\S+/graduated_notifications/#{graduated_notification1.id}\z}, wait: 10)
    expect(page).to have_css("h1", text: "Graduated notification")
    expect(page).to have_content("alice@example.com")
    expect(page).to have_content("User Bikes")

    # Back from notification show: filtered search restored
    page.go_back
    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("turbo-frame#graduated_notifications_results_frame table.ui-table", wait: 10)
    expect(page).to have_css("tbody tr", count: 1, wait: 10)
    expect(page).to have_field("search_email", with: "alice@example.com")
    expect(page).to have_content("alice@example.com")
    expect(page).not_to have_content("bob@example.com")
    expect(page).to have_css(".hw-combobox", count: 1, wait: 10)

    within("tbody tr") { find("a[href^='/bikes/']").click }

    expect(page).to have_current_path(%r{/bikes/#{bike1.id}(\?|\z)}, wait: 10)
    expect(page).to have_css(".organized-access-panel")

    # Back from bike show: filtered search restored
    page.go_back
    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("turbo-frame#graduated_notifications_results_frame table.ui-table", wait: 10)
    expect(page).to have_css("tbody tr", count: 1, wait: 10)
    expect(page).to have_field("search_email", with: "alice@example.com")
    expect(page).to have_content("alice@example.com")
    expect(page).not_to have_content("bob@example.com")
    expect(page).to have_css(".hw-combobox", count: 1, wait: 10)

    # Clear email filter for status-dropdown test
    fill_in "search_email", with: ""
    find("#search-button").click
    expect(page).to have_css("tbody tr", count: 2, wait: 10)
    expect(page).to have_content("alice@example.com")
    expect(page).to have_content("bob@example.com")
    expect(page).not_to have_content("carol@example.com")

    # Status dropdown advances URL; switching to Marked Not Graduated shows only carol
    within("turbo-frame#graduated_notifications_results_frame") { find("[data-ui--dropdown-target='button']").click }
    click_link "Marked Not Graduated"

    expect(page).to have_current_path(/search_status=marked_remaining/, wait: 10)
    expect(page).to have_button(text: /marked not graduated/i)
    expect(page).to have_css("tbody tr", count: 1, wait: 10)
    expect(page).to have_content("carol@example.com")
    expect(page).not_to have_content("alice@example.com")
    expect(page).not_to have_content("bob@example.com")

    # Reload preserves URL + dropdown selection
    visit page.current_url
    expect(page).to have_current_path(/search_status=marked_remaining/, wait: 10)
    expect(page).to have_css("turbo-frame#graduated_notifications_results_frame table.ui-table", wait: 10)
    expect(page).to have_button(text: /marked not graduated/i)
    expect(page).to have_css("tbody tr", count: 1, wait: 10)
    expect(page).to have_content("carol@example.com")
    expect(page).not_to have_content("alice@example.com")
    expect(page).not_to have_content("bob@example.com")

    # Submit again — hidden search_status field preserves the selection
    find("#search-button").click
    expect(page).to have_current_path(/search_status=marked_remaining/, wait: 10)
    expect(page).to have_content("carol@example.com")

    # search_secondary also persists via hidden field
    visit "#{graduated_notifications_path}?search_secondary=true"
    expect(page).to have_css("turbo-frame#graduated_notifications_results_frame table.ui-table", wait: 10)
    fill_in "search_email", with: "alice@example.com"
    find("#search-button").click
    expect(page).to have_current_path(/search_secondary=true/, wait: 10)
    expect(page).to have_current_path(/search_email=alice/, wait: 10)
  end
end
