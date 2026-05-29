# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Bike search", :js, type: :system do
  include_context :geocoder_stubbed_bounding_box
  include_context :geocoder_default_location

  let(:blue) { FactoryBot.create(:color, name: "Blue") }
  let(:red) { FactoryBot.create(:color, name: "Red") }

  let!(:blue_stolen_bike_nyc) { FactoryBot.create(:stolen_bike_in_nyc, primary_frame_color: blue) }
  let!(:red_stolen_bike_nyc) { FactoryBot.create(:stolen_bike_in_nyc, primary_frame_color: red) }
  let!(:blue_stolen_bike_la) { FactoryBot.create(:stolen_bike_in_los_angeles, primary_frame_color: blue) }
  let!(:red_non_stolen_bike) { FactoryBot.create(:bike, primary_frame_color: red) }

  before do
    Autocomplete::Loader.load_all(%w[Color])
    # Ensure gear types exist so bike show page doesn't write during readonly mode
    RearGearType.fixed
    FrontGearType.fixed
  end

  def click_first_bike_and_go_back
    first(".bike-box-item .title-link a").click
    expect(page).to have_css("h1.bike-title", wait: 10)
    page.go_back
    expect(page).to have_css(".bike-box-item", wait: 10)
  end

  it "filters by color and location" do
    # Visit a different page first to establish history, then navigate to search
    visit "/"
    visit "/search/registrations"

    expect(page).to have_css(".bike-box-item", wait: 10)
    expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)

    # Initial load doesn't add a duplicate history entry, so back button returns to previous page
    page.go_back
    expect(page).to have_current_path("/", wait: 5)
    page.go_forward
    expect(page).to have_css(".bike-box-item", wait: 10)

    # Select "All registrations" stolenness
    choose("stolenness_all", allow_label_click: true, visible: :all)

    # Search for Blue via the combobox
    find(".hw-combobox__input").set("Blue")
    expect(page).to have_css(".hw-combobox__option", text: "that are", wait: 5)
    find(".hw-combobox__option", text: "Blue", match: :first).click

    # Submit search
    find("#search-button").click

    expect(page).to have_css(".bike-box-item", count: 2, wait: 10)
    expect(page).to have_content("Blue")
    expect(page).not_to have_content("Red")

    click_first_bike_and_go_back

    # Switch to proximity search for NYC
    choose("stolenness_proximity", allow_label_click: true, visible: :all)
    fill_in "distance", with: "200"
    fill_in "location", with: "New York, NY"
    find("#search-button").click

    # Only the blue NYC bike (proximity + color filter still active)
    expect(page).to have_css(".bike-box-item", count: 1, wait: 10)
    expect(page).to have_content("Blue")

    click_first_bike_and_go_back

    # Remove the color filter by clearing the combobox, then search again
    find(".hw-combobox__chip__remover").click
    find("#search-button").click

    # Now both NYC stolen bikes appear
    expect(page).to have_css(".bike-box-item", count: 2, wait: 10)

    click_first_bike_and_go_back
  end

  it "reloads results when going back to the initial search page" do
    visit "/"
    visit "/search/registrations"
    expect(page).to have_css(".bike-box-item", wait: 10)

    # Search Blue, then view a result
    choose("stolenness_all", allow_label_click: true, visible: :all)
    find(".hw-combobox__input").set("Blue")
    expect(page).to have_css(".hw-combobox__option", text: "that are", wait: 5)
    find(".hw-combobox__option", text: "Blue", match: :first).click
    find("#search-button").click
    expect(page).to have_css(".bike-box-item", count: 2, wait: 10)

    first(".bike-box-item .title-link a").click
    expect(page).to have_css("h1.bike-title", wait: 10)

    # Back to the Blue results, then back again to the initial search page. Its
    # results must reload rather than restoring a Turbo snapshot whose frame is
    # stuck in the [busy] loading state (results hidden under the spinner
    # overlay) - the "everything fails after going back from a search" bug.
    page.go_back
    expect(page).to have_css(".bike-box-item", wait: 10)
    page.go_back
    expect(page).to have_css(".bike-box-item", wait: 10)
  end

  it "auto-submits only once when going back to a re-fetched search page" do
    visit "/"
    visit "/search/registrations"
    expect(page).to have_css(".bike-box-item", wait: 10)
    choose("stolenness_all", allow_label_click: true, visible: :all)

    # Two searches in a row, then back to the first - the user's repro.
    find(".hw-combobox__input").set("Red")
    expect(page).to have_css(".hw-combobox__option", text: "that are", wait: 5)
    find(".hw-combobox__option", text: "Red", match: :first).click
    find("#search-button").click
    expect(page).to have_css(".bike-box-item", count: 2, wait: 10)

    find(".hw-combobox__chip__remover").click
    find(".hw-combobox__input").set("Blue")
    expect(page).to have_css(".hw-combobox__option", text: "that are", wait: 5)
    find(".hw-combobox__option", text: "Blue", match: :first).click
    find("#search-button").click
    expect(page).to have_css(".bike-box-item", count: 2, wait: 10)

    # On back, connect() and the turbo:load handler both run the empty-results
    # auto-submit. Whether the restoration re-fetches (auto-submit runs) or
    # restores a cached snapshot (no auto-submit) varies, but it must never fire
    # the auto-submit twice: without the guard the duplicate requestSubmit is
    # aborted by Turbo (the uncaught AbortError in the console).
    page.execute_script("window.__submitStarts = 0; document.addEventListener('turbo:submit-start', () => { window.__submitStarts += 1 })")
    page.go_back
    expect(page).to have_css(".bike-box-item", count: 2, wait: 10)
    expect(page.evaluate_script("window.__submitStarts")).to be <= 1
  end
end
