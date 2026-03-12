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

  before { Autocomplete::Loader.load_all(%w[Color]) }

  it "filters by color and location" do
    visit "/search/registrations"

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

    # Switch to proximity search for NYC
    find("label[for='stolenness_proximity']").click
    find("#distance").set("200")
    find("#location").set("New York, NY")
    find("#search-button").click

    # Only the blue NYC bike (proximity + color filter still active)
    expect(page).to have_css(".bike-box-item", count: 1, wait: 10)
    expect(page).to have_content("Blue")

    # Remove the color filter by clearing the Select2, then search again
    find(".select2-selection__choice__remove").click
    find("#search-button").click

    # Now both NYC stolen bikes appear
    expect(page).to have_css(".bike-box-item", count: 2, wait: 10)
  end
end
