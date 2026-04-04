# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized bikes search", :js, type: :system do
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:) }
  let(:enabled_feature_slugs) { %w[bike_search csv_exports impound_bikes registration_notes] }
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

  def expect_settings_open
    expect(find(".settings-list", visible: :all)["class"]).not_to include("tw:hidden!")
  end

  def open_settings_if_not
    # if settings
    if find(".settings-list", visible: :all)["class"].include?("tw:hidden!")
      click_button "settings"
    end
  end

  it "searches by email and serial" do
    # Create enough bikes to trigger pagination (default per_page is 10)
    FactoryBot.create_list(:bike_organized, 10, creation_organization: organization)

    # Visit a different page first to establish history, then navigate to bikes
    visit "/"
    visit bikes_path
    # Results load via turbo auto-submit (search--form controller)
    expect(page).to have_css("turbo-frame#organized_bikes_results_frame table", wait: 10)
    expect(page).to have_css("tbody tr", minimum: 2)

    # search_no_js should NOT be in the URL (removed by JS controller)
    expect(page).not_to have_current_path(/search_no_js/)

    # Initial load uses replaceState, so back button returns to the previous page (not a duplicate search entry)
    page.go_back
    expect(page).to have_current_path("/", wait: 5)
    page.go_forward
    expect(page).to have_css("table", wait: 10)
    expect(page).to have_css("tbody tr", minimum: 2)

    # Search by serial number
    fill_in "serial", with: bike1.serial_number
    find("#search-button").click

    expect(page).to have_current_path(/serial=/, wait: 10)
    expect(page).to have_css("tbody tr", count: 1)

    # Clear serial and search by email
    fill_in "serial", with: ""
    fill_in "search_email", with: "alice@example.com"
    find("#search-button").click

    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("tbody tr", count: 1)
    expect(page).to have_content("alice@example.com")
    expect(page).not_to have_content("bob@example.com")

    # submits when enter is pressed twice
    visit bikes_path
    expect(page).to have_css("table", wait: 10)

    fill_in "search_email", with: "alice@example.com"
    find("#search_email").send_keys(:return)

    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("tbody tr", count: 1)

    visit bikes_path
    expect(page).to have_css("table", wait: 10)
    expect(page).to have_css("tbody tr", minimum: 10)

    # Pagination should be visible with multiple pages
    expect(page).to have_css(".paginate-container a", minimum: 1)

    # Click page 2 — turbo frame updates without full reload
    click_link "2"
    expect(page).to have_current_path(/page=2/, wait: 10)
    expect(page).to have_css("table", wait: 10)
    expect(page).to have_css("tbody tr", minimum: 1)

    # Verify that it preserves turbo-frame after search submissions
    # Initial auto-submit loads results via turbo_stream
    expect(page).to have_css("turbo-frame#organized_bikes_results_frame table", wait: 10)
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

    # Go back
    page.go_back
    expect(page).to have_css("tbody tr", count: 10, wait: 10)
    # Open settings to reveal the export link
    open_settings_if_not
    click_link "Create export of searched registrations"

    expect(page).to have_current_path(%r{/o/\S+/exports/new}, wait: 10)
    all_bike_ids = organization.bikes.pluck(:id).sort
    export_ids = find("#export_custom_bike_ids", visible: :all).value.split(", ").map(&:to_i).sort
    expect(export_ids).to eq(all_bike_ids)

    # Search by notes
    FactoryBot.create(:bike_organization_note, bike: bike1, body: "red lock on rack")
    page.go_back
    expect(page).to have_css("table", wait: 10)

    open_settings_if_not
    click_button "show notes search"
    fill_in "search_notes", with: "red lock"
    find("#search-button").click

    expect(page).to have_current_path(/search_notes=red/, wait: 10)
    expect(page).to have_css("tbody tr", count: 1)
    expect(page).to have_content("alice@example.com")
  end

  context "with stolen and impounded bikes" do
    let(:enabled_feature_slugs) { %w[bike_search impound_bikes] }
    let!(:stolen_bike) { FactoryBot.create(:bike_organized, :with_stolen_record, creation_organization: organization) }
    let!(:impounded_bike) { FactoryBot.create(:bike_organized, :impounded, creation_organization: organization) }

    it "filters by status radios" do
      visit "#{bikes_path}?search_status=all"
      expect(page).to have_css("table", wait: 10)
      expect(page).to have_css("tbody tr", minimum: 4, wait: 10)

      # Open settings and choose "only stolen"
      open_settings_if_not
      choose("search_status_stolen", allow_label_click: true, visible: :all)
      expect(page).to have_current_path(/search_status=stolen/, wait: 10)
      expect(page).to have_css("table", wait: 10)
      expect(page).to have_css("tbody tr", count: 1)
      expect(page).to have_text("1 registration matching")
      expect(page).to have_text("only stolen")

      # Settings persisted open via localStorage; choose "only impounded"
      expect_settings_open
      choose("search_status_impounded", allow_label_click: true, visible: :all)
      expect(page).to have_current_path(/search_status=impounded/, wait: 10)
      expect(page).to have_css("table", wait: 10)
      expect(page).to have_css("tbody tr", count: 1)

      # Doesn't have export, because no csv_export feature
      expect_settings_open
      expect(page).to_not have_text "Create export of searched registrations"

      # Choose "not stolen or impounded"
      choose("search_status_with_owner", allow_label_click: true, visible: :all)
      expect(page).to have_current_path(/search_status=with_owner/, wait: 10)
      expect(page).to have_css("table", wait: 10)
      expect(page).to have_css("tbody tr", count: 2)
      expect(page).to have_text("not stolen or impounded")

      # Choose "All" to show everything
      choose("search_status_all", allow_label_click: true, visible: :all)
      expect(page).to have_current_path(/search_status=all/, wait: 10)
      expect(page).to have_css("table", wait: 10)
      expect(page).to have_css("tbody tr", minimum: 4, wait: 10)
    end
  end

  context "with avery_export enabled" do
    let(:enabled_feature_slugs) { %w[bike_search avery_export reg_address bike_stickers csv_exports] }
    let!(:avery_bike) do
      bike = FactoryBot.create(:bike_organized, :with_address_record, creation_organization: organization)
      bike.current_ownership.update!(owner_name: "Test Owner")
      bike
    end
    let!(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, organization:, bike: bike1) }
    let!(:unlinked_sticker) { FactoryBot.create(:bike_sticker, organization:) }

    it "toggles avery export column via checkbox" do
      visit bikes_path
      expect(page).to have_css("table", wait: 10)
      expect(page).not_to have_css("th.avery_cell")
      expect(page).not_to have_css("th.assign_bike_sticker_cell")

      # Open settings and check avery — triggers page reload with param
      open_settings_if_not
      check "avery_cell"
      expect(page).to have_current_path(/search_avery_export=true/, wait: 10)
      # Avery column should be visible with check mark for exportable bike
      expect(page).to have_css("th.avery_cell")
      expect(page).to have_css("td.avery_cell", text: "✓")

      expect_settings_open
      # Settings panel is already open (persisted via localStorage)
      # Uncheck avery — triggers page reload without param
      expect(page).to have_field("avery_cell", checked: true, wait: 5)
      uncheck "avery_cell"
      expect(page).not_to have_current_path(/search_avery_export/, wait: 10)
      expect(page).not_to have_css("th.avery_cell")

      # Open settings and choose "only with address"
      choose("search_address_with_street", allow_label_click: true, visible: :all)
      expect(page).to have_current_path(/search_address=with_street/, wait: 10)
      expect(page).to have_css("table", wait: 10)
      expect(page).to have_css("tbody tr", count: 1)
      expect(page).to have_text("1 registration matching")
      expect(page).to have_text("only with address")

      expect_settings_open
      click_link "Create export of searched registrations"
      expect(page).to have_current_path(%r{/o/\S+/exports/new}, wait: 10)
      export_ids = find("#export_custom_bike_ids", visible: :all).value.split(", ").map(&:to_i).sort
      expect(export_ids).to eq([avery_bike.id])
      page.go_back
      expect(page).to have_css("tbody tr", count: 1, wait: 10)

      expect_settings_open
      choose("search_stickers_with", allow_label_click: true, visible: :all)
      expect(page).to have_current_path(/search_stickers=with/, wait: 10)
      expect(page).to have_css("table", wait: 10)
      expect(page).to have_css("tbody tr", count: 0)
      expect(page).to have_text("0 registrations matching")
      expect(page).to have_text("only with address")
      expect(page).to have_text("only with stickers")

      choose("search_address_", allow_label_click: true, visible: :all)
      expect(page).to have_current_path(/search_stickers=with/, wait: 10)
      expect(page).to have_css("table", wait: 10)
      expect(page).to have_css("tbody tr", count: 1)

      # Visit with bike_sticker param to test assign_bike_sticker column
      visit "#{bikes_path}?bike_sticker=#{unlinked_sticker.code}"
      expect(page).to have_css("table", wait: 10)
      expect(page).to have_css("th.assign_bike_sticker_cell")
      expect(page).to have_css("td.assign_bike_sticker_cell a", text: "Link", minimum: 1)

      # Click the first "Link" to assign the sticker to a bike
      first("td.assign_bike_sticker_cell a").click
      expect(page).to have_current_path(%r{/bikes/\d+}, wait: 10)
      expect(page).to have_content("claimed")
      expect(unlinked_sticker.reload.bike).to be_present
    end
  end
end
