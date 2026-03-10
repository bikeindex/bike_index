# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized bikes search", :js, type: :system do
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:) }
  let(:enabled_feature_slugs) { %w[bike_search] }
  let(:user) { FactoryBot.create(:organization_admin, organization:) }
  let(:bikes_path) { "/o/#{organization.to_param}/bikes" }

  let!(:bike1) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: "alice@example.com") }
  let!(:bike2) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: "bob@example.com") }

  before do
    # Ensure gear types exist so bike show page doesn't write during readonly mode
    RearGearType.fixed
    FrontGearType.fixed
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
  end

  it "searches by email" do
    # Create enough bikes to trigger pagination (default per_page is 10)
    FactoryBot.create_list(:bike_organized, 10, creation_organization: organization)

    visit bikes_path
    # Results load via turbo auto-submit (search--form controller)
    expect(page).to have_css("turbo-frame#organized_bikes_results_frame table.table", wait: 10)
    expect(page).to have_css("tbody tr", minimum: 2)

    # search_no_js should NOT be in the URL (removed by JS controller)
    expect(page).not_to have_current_path(/search_no_js/)
    expect(page).to have_css("table.table", wait: 10)
    expect(page).to have_css("tbody tr", minimum: 2)

    fill_in "search_email", with: "alice@example.com"
    find("#search-button").click

    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("tbody tr", count: 1)
    expect(page).to have_content("alice@example.com")
    expect(page).not_to have_content("bob@example.com")

    # submits when enter is pressed twice
    visit bikes_path
    expect(page).to have_css("table.table", wait: 10)

    fill_in "search_email", with: "alice@example.com"
    find("#search_email").send_keys(:return)

    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("tbody tr", count: 1)

    visit bikes_path
    expect(page).to have_css("table.table", wait: 10)
    expect(page).to have_css("tbody tr", minimum: 10)

    # Pagination should be visible with multiple pages
    expect(page).to have_css(".paginate-container a", minimum: 1)

    # Click page 2 — turbo frame updates without full reload
    click_link "2"
    expect(page).to have_current_path(/page=2/, wait: 10)
    expect(page).to have_css("table.table", wait: 10)
    expect(page).to have_css("tbody tr", minimum: 1)

    # Verify that it preserves turbo-frame after search submissions
    # Initial auto-submit loads results via turbo_stream
    expect(page).to have_css("turbo-frame#organized_bikes_results_frame table.table", wait: 10)
    # turbo-frame element must still exist after turbo_stream.update
    expect(page).to have_css("turbo-frame#organized_bikes_results_frame")

    # Search again — this fails if the frame was removed by turbo_stream.replace
    fill_in "search_email", with: "alice@example.com"
    find("#search-button").click
    expect(page).to have_css("turbo-frame#organized_bikes_results_frame", wait: 10)
    expect(page).to have_css("tbody tr", count: 1)

    # Third submission to confirm frame is still intact
    fill_in "search_email", with: ""
    find("#search-button").click
    expect(page).to have_css("tbody tr", count: 10, wait: 10)
    expect(page).to have_css("turbo-frame#organized_bikes_results_frame")

    # clicking a bike navigates to the bike show page with organized panel
    first("a[aria-label='View bike']").click

    expect(page).to have_current_path(%r{/bikes/\d+}, wait: 10)

    expect(page).to have_css(".organized-access-panel")
    expect(page).to have_content(/#{organization.name}\s+Access Panel/i)
  end

  context "with avery_export enabled" do
    let(:enabled_feature_slugs) { %w[bike_search avery_export] }
    let!(:avery_bike) do
      bike = FactoryBot.create(:bike_organized, :with_address_record, creation_organization: organization)
      bike.current_ownership.update!(owner_name: "Test Owner")
      bike
    end

    it "toggles avery export column via checkbox" do
      visit bikes_path
      expect(page).to have_css("table.table", wait: 10)
      expect(page).not_to have_css("th.avery_cell")

      # Open settings and check avery — triggers page reload with param
      click_button "settings"
      check "avery_cell"
      expect(page).to have_current_path(/search_avery_export=true/, wait: 10)
      # Avery column should be visible with check mark for exportable bike
      expect(page).to have_css("th.avery_cell", visible: true)
      expect(page).to have_css("td.avery_cell", text: "✓")

      # Settings panel is already open (persisted via localStorage)
      # Uncheck avery — triggers page reload without param
      expect(page).to have_field("avery_cell", checked: true, wait: 5)
      uncheck "avery_cell"
      expect(page).not_to have_current_path(/search_avery_export/, wait: 10)
      expect(page).not_to have_css("th.avery_cell")
    end
  end
end
