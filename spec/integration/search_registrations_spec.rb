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
    find("label[for='stolenness_all']").click

    # Search for Blue via the Select2 combobox
    find(".select2-container").click
    find(".select2-search__field").set("Blue")
    expect(page).to have_content("that are", wait: 5)
    find(".select2-results__option", text: "Blue", match: :first).click

    # Submit search
    find("#search-button").click

    expect(page).to have_css(".bike-box-item", count: 2, wait: 10)
    expect(page).to have_content("Blue")
    expect(page).not_to have_content("Red")

    click_first_bike_and_go_back

    # Switch to proximity search for NYC
    find("label[for='stolenness_proximity']").click
    find("#distance").set("200")
    find("#location").set("New York, NY")
    find("#search-button").click

    # Only the blue NYC bike (proximity + color filter still active)
    expect(page).to have_css(".bike-box-item", count: 1, wait: 10)
    expect(page).to have_content("Blue")

    click_first_bike_and_go_back

    # Remove the color filter by clearing the Select2, then search again
    find(".select2-selection__choice__remove").click
    find("#search-button").click

    # Now both NYC stolen bikes appear
    expect(page).to have_css(".bike-box-item", count: 2, wait: 10)

    click_first_bike_and_go_back
  end
end
