# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized registrations search", :js, type: :system do
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:, created_at: 5.years.ago) }
  let(:enabled_feature_slugs) { %w[bike_search csv_exports impound_bikes registration_notes show_bulk_import] }
  let(:user) { FactoryBot.create(:organization_admin, organization:) }
  let(:bikes_path) { "/o/#{organization.to_param}/registrations" }

  let!(:bike1) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: "alice@example.com", created_at: 2.years.ago) }
  let!(:bike2) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: "bob@example.com", created_at: 3.days.ago) }

  before do
    # Ensure gear types exist so bike show page doesn't write during readonly mode
    RearGearType.fixed
    FrontGearType.fixed
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
  end

  def settings_selector
    "[data-org--registration-search-target='settings']"
  end

  def expect_settings_open
    expect(find(settings_selector, visible: :all)["class"]).not_to include("tw:hidden!")
  end

  def open_settings_if_not
    if find(settings_selector, visible: :all)["class"].include?("tw:hidden!")
      click_button "settings"
    end
  end

  def rendered_bike_ids
    page.all("tbody tr a[href^='/bikes/']").map { |a| Integer(a[:href][%r{/bikes/(\d+)}, 1]) }.sort
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
    expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES, "select-name")

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

    # filters by period and custom time range — 12 bikes total: bike1 (2.years.ago), bike2 (3.days.ago), 10 create_list (now)
    # "past year" excludes bike1 (2 years ago)
    click_link "past year"
    expect(page).to have_current_path(/period=year/, wait: 10)
    expect(page).to have_text("0 registration matching")

    fill_in "search_notes", with: ""
    find("#search-button").click
    expect(page).to have_current_path(/period=year/, wait: 10)

    # "past day" additionally excludes bike2 (3 days ago)
    click_link "past day"
    expect(page).to have_current_path(/period=day/, wait: 10)
    expect(page).to have_text("1 registration matching")

    # Custom time range narrowed to a ±1 day window around bike2.created_at — matches bike2 only
    click_button "custom"
    start_str = (bike2.created_at - 1.day).strftime("%Y-%m-%dT%H:%M")
    end_str = (bike2.created_at + 1.day).strftime("%Y-%m-%dT%H:%M")
    page.execute_script("document.getElementById('start_time_selector').value = '#{start_str}'")
    page.execute_script("document.getElementById('end_time_selector').value = '#{end_str}'")
    page.execute_script("document.querySelector(\"[data-controller~='ui--period-select'] button[type='submit']\").click()")
    expect(page).to have_current_path(/period=custom/, wait: 10)
    expect(rendered_bike_ids).to eq([bike2.id])

    # Combined email + period: bob is within "past year" (3 days ago), alice is not (2 years ago)
    visit "#{bikes_path}?search_email=bob@example.com&period=year"
    expect(page).to have_css("table", wait: 10)
    expect(page).to have_field("search_email", with: "bob@example.com")
    expect(rendered_bike_ids).to eq([bike2.id])

    # JS (application.js + TimeLocalizer) sets a timezone cookie from window.localTimezone.
    # The server reads it in set_locale and uses it to bucket chart data via groupdate.
    # Run this before the custom period click below — that submission posts a timezone
    # param, which gets persisted in session[:timezone] and overrides the cookie.
    expect(page.driver.browser.manage.cookie_named("timezone")[:value]).to be_present

    # 5 AM UTC = 9 PM PDT (or 12 AM CDT) the previous day, so PDT and CDT fall on different days.
    bulk_import_created_at = 14.days.ago.utc.beginning_of_day + 5.hours
    FactoryBot.create(:bulk_import, organization:, created_at: bulk_import_created_at)
    la_date_key = bulk_import_created_at.in_time_zone("America/Los_Angeles").strftime("%Y-%-m-%-d")
    cdt_date_key = bulk_import_created_at.in_time_zone("America/Chicago").strftime("%Y-%-m-%-d")
    expect(la_date_key).not_to eq(cdt_date_key)

    # Replace the cookie via JS the same way the app does, so attributes (SameSite, path)
    # match and Chrome reliably overwrites the existing cookie set on previous loads.
    page.execute_script("document.cookie = 'timezone=America/Los_Angeles;path=/;max-age=31536000;SameSite=Lax'")
    expect(page.driver.browser.manage.cookie_named("timezone")[:value]).to eq("America/Los_Angeles")

    visit "/o/#{organization.to_param}/bulk_imports?render_chart=true&period=month"
    expect(page).to have_css("table", wait: 10)
    # Chartkick init renders inline as array tuples; LA bucket has count 1, CDT bucket has 0
    expect(page.html).to include(%(["#{la_date_key}",1]))
    expect(page.html).to include(%(["#{cdt_date_key}",0]))
  end

  context "with stolen and impounded bikes" do
    let(:enabled_feature_slugs) { %w[bike_search impound_bikes] }
    let!(:stolen_bike) { FactoryBot.create(:bike_organized, :with_stolen_record, creation_organization: organization) }
    let!(:impounded_bike) { FactoryBot.create(:bike_organized, :impounded, creation_organization: organization) }

    it "filters by status radios" do
      visit "#{bikes_path}?search_status=all"
      expect(page).to have_css("table", wait: 10)
      expect(page).to have_css("tbody tr", minimum: 4, wait: 10)

      # Default columns are visible
      expect(page).to have_css("th.manufacturer_cell", visible: :visible)
      expect(page).to have_css("th.owner_email_cell", visible: :visible)
      expect(page).to have_css("th.stolen_cell", visible: :visible)
      # Non-default columns are hidden
      expect(page).to have_css("th.serial_number_cell", visible: :hidden)
      expect(page).to have_css("th.url_cell", visible: :hidden)
      expect(page).to have_css("th.impounded_cell", visible: :hidden)
      # Uncheck a default column — it hides
      open_settings_if_not
      uncheck "manufacturer_cell"
      expect(page).to have_css("th.manufacturer_cell", visible: :hidden)
      expect(page).to have_css("td.manufacturer_cell", visible: :hidden, minimum: 1)
      # Check a non-default column — it shows
      check "serial_number_cell"
      expect(page).to have_css("th.serial_number_cell", visible: :visible)
      expect(page).to have_css("td.serial_number_cell", visible: :visible, minimum: 1)
      # Show impounded column
      check "impounded_cell"
      expect(page).to have_css("th.impounded_cell", visible: :visible)

      # Choose "only stolen"
      choose("search_status_stolen", allow_label_click: true, visible: :all)
      expect(page).to have_current_path(/search_status=stolen/, wait: 10)
      expect(page).to have_css("table", wait: 10)
      expect(page).to have_css("tbody tr", count: 1)
      expect(page).to have_text("1 registration matching")
      expect(page).to have_text("only stolen")
      # Column choices persist after the search
      expect(page).to have_css("th.manufacturer_cell", visible: :hidden)
      expect(page).to have_css("th.serial_number_cell", visible: :visible)
      expect(page).to have_css("th.impounded_cell", visible: :visible)

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
      # Column choices still persist
      expect(page).to have_css("th.manufacturer_cell", visible: :hidden)
      expect(page).to have_css("th.serial_number_cell", visible: :visible)
      expect(page).to have_css("th.impounded_cell", visible: :visible)
    end
  end

  context "multi serial search" do
    let(:multi_serial_path) { "/o/#{organization.to_param}/registrations/multi_search" }

    let!(:bike_a) { FactoryBot.create(:bike_organized, serial_number: "SERIAL111", creation_organization: organization) }
    let!(:bike_b) { FactoryBot.create(:bike_organized, serial_number: "SERIAL222", creation_organization: organization) }
    let!(:other_org_bike) { FactoryBot.create(:bike, serial_number: "SERIAL333") }

    it "searches multiple serials and shows results" do
      visit multi_serial_path

      expect(page).to have_content(/multiple serial search/i)
      expect(page).to have_css("[data-controller~='org--multi-serial-search']", wait: 5)

      find("textarea#serials").set("SERIAL111, SERIAL222, NONEXISTENT")
      click_button "Search serials"

      # Chips update with results
      expect(page).to have_css("#chip_2.tw\\:bg-gray-300", wait: 15)

      # Results sorted by chip order, empty results removed
      expect(page).to have_css(".multi-search-serial-result", count: 2)
      expect(page).not_to have_content("No matches found")
      expect(page).not_to have_content("SERIAL333")
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
      expect(page).not_to have_css("th.avery_cell", visible: :visible)
      expect(page).not_to have_css("th.assign_bike_sticker_cell")

      # Open settings and check avery — toggles column visibility client-side
      open_settings_if_not
      check "avery_cell"
      # Avery column should be visible with check mark for exportable bike
      expect(page).to have_css("th.avery_cell", visible: :visible)
      expect(page).to have_css("td.avery_cell", text: "✓")

      # Uncheck avery — hides column client-side
      uncheck "avery_cell"
      expect(page).not_to have_css("th.avery_cell", visible: :visible)

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
      expect(page).to have_css("td.assign_bike_sticker_cell a", text: "link sticker", minimum: 1)

      # Click the first "Link" to assign the sticker to a bike
      first("td.assign_bike_sticker_cell a").click
      expect(page).to have_current_path(%r{/bikes/\d+}, wait: 10)
      expect(page).to have_content("claimed")
      expect(unlinked_sticker.reload.bike).to be_present
    end
  end
end
