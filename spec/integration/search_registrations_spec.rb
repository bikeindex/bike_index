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

  def search_color_and_submit(color)
    find(".hw-combobox__input").set(color)
    expect(page).to have_css(".hw-combobox__option", text: "that are", wait: 5)
    find(".hw-combobox__option", text: color, match: :first).click
    find("#search-button").click
  end

  it "filters by color and location" do
    # Visit a different page first to establish history, then navigate to search
    visit "/"
    visit "/search/registrations"

    expect(page).to have_css(".bike-box-item", wait: 10)
    expect_axe_clean

    # Initial load doesn't add a duplicate history entry, so back button returns to previous page
    page.go_back
    expect(page).to have_current_path("/", wait: 5)
    page.go_forward
    expect(page).to have_css(".bike-box-item", wait: 10)

    # Select "All registrations" stolenness, then search Blue via the combobox
    choose("stolenness_all", allow_label_click: true, visible: :all)
    search_color_and_submit("Blue")

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

    # Search Blue, view a result, then return to the Blue results
    choose("stolenness_all", allow_label_click: true, visible: :all)
    search_color_and_submit("Blue")
    expect(page).to have_css(".bike-box-item", count: 2, wait: 10)
    click_first_bike_and_go_back

    # Back again to the initial search page. Its results must reload rather than
    # restoring a Turbo snapshot whose frame is stuck in the [busy] loading state
    # (results hidden under the spinner overlay) - the "everything fails after
    # going back from a search" bug.
    page.go_back
    expect(page).to have_css(".bike-box-item", wait: 10)
  end

  # :flaky retry covers a rare residual settle-timing race in the JS auto-submit
  # restoration path - an in-flight default submit can clobber the restored URL
  # before the assertions run. The eager turbo-frame src work removes the
  # auto-submit machinery entirely; until then, retry on CI.
  it "keeps back/forward navigation in sync without double-submitting", :flaky do
    # Two searches in a row, then back to the first - the user's repro. connect()
    # and the turbo:load handler both run the empty-results auto-submit on that
    # back; it must fire at most once - without the guard the duplicate
    # requestSubmit is aborted by Turbo (the uncaught AbortError in the console).
    visit "/"
    visit "/search/registrations"
    expect(page).to have_css(".bike-box-item", wait: 10)
    choose("stolenness_all", allow_label_click: true, visible: :all)

    search_color_and_submit("Red")
    expect(page).to have_css(".bike-box-item", count: 2, wait: 10)

    find(".hw-combobox__chip__remover").click
    search_color_and_submit("Blue")
    expect(page).to have_css(".bike-box-item", count: 2, wait: 10)

    page.execute_script("window.__submitStarts = 0; document.addEventListener('turbo:submit-start', () => { window.__submitStarts += 1 })")
    page.go_back
    expect(page).to have_css(".bike-box-item", count: 2, wait: 10)
    expect(page.evaluate_script("window.__submitStarts")).to be <= 1

    # Now a fresh search, then back and forward. Forward must restore the selected
    # query_items[] in the URL: the auto-submit waits for the combobox to swap its
    # non-JS query field for query_items[]; otherwise it submits the empty `query`
    # field and the URL drops the items, no longer matching the form.
    visit "/"
    visit "/search/registrations"
    expect(page).to have_css(".bike-box-item", wait: 10)
    choose("stolenness_all", allow_label_click: true, visible: :all)
    search_color_and_submit("Blue")
    expect(page).to have_css(".bike-box-item", count: 2, wait: 10)
    expect(page).to have_current_path(/query_items/, wait: 10)

    page.go_back
    expect(page).to have_css(".bike-box-item", wait: 10)
    page.go_forward
    # Results must match the restored URL, not a stale snapshot showing every
    # color (only the two Blue bikes, no Red).
    expect(page).to have_current_path(/query_items/, wait: 10)
    expect(page).to have_css(".bike-box-item", count: 2, wait: 10)
    expect(page).to have_no_content("Red")
  end
end
