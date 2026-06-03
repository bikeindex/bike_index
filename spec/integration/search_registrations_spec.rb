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

  # Assert the results *inside the eager turbo-frame* match a color search, so it
  # proves the frame itself reconciled to the URL (reloadFrameIfUrlStale) - unlike
  # the combobox chip, which lives in the form outside the frame and is restored
  # by Turbo's page snapshot. Red and Blue both return 2 bikes, so the colors,
  # not the count, are what distinguish the frame's contents.
  def expect_results_frame_color(shown, hidden)
    # Count-based, not have_content/have_no_content: the frame reloads through
    # transient states on back/forward, and a bare have_content("...Red") /
    # have_no_content("...Blue") can each pass on a transient frame (Red still
    # showing before the reload, Blue not loaded yet). Requiring exactly 2 of the
    # shown color and 0 of the hidden only holds once the frame has settled.
    within("turbo-frame#search_registrations_results_frame") do
      expect(page).to have_css(".bike-box-item", text: "Primary colors: #{shown}", count: 2, wait: 10)
      expect(page).to have_css(".bike-box-item", text: "Primary colors: #{hidden}", count: 0, wait: 10)
    end
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
    # The applied Blue filter shows as the combobox chip. (have_content("Blue")
    # would also match the footer's "Bike Index Blue Sky" link, so it can't tell
    # whether the filter actually took.)
    expect(page).to have_css(".hw-combobox__chip", text: "Blue")
    expect(page).not_to have_content("Red")

    click_first_bike_and_go_back

    # Switch to proximity search for NYC
    choose("stolenness_proximity", allow_label_click: true, visible: :all)
    fill_in "distance", with: "200"
    fill_in "location", with: "New York, NY"
    find("#search-button").click

    # Only the blue NYC bike (proximity + color filter still active)
    expect(page).to have_css(".bike-box-item", count: 1, wait: 10)
    expect(page).to have_css(".hw-combobox__chip", text: "Blue")

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

  it "restores the search and results on back navigation, without re-submitting" do
    # Search Red, then Blue, then go back to the Red search. On back, both must
    # reconcile to the restored URL: the results frame (reloadFrameIfUrlStale
    # reloads it from the address bar - asserted via the bikes' colors inside the
    # frame, which differ from Blue's; both searches return 2 bikes, so the count
    # alone wouldn't catch a stale frame) and the search form (restored by Turbo's
    # page snapshot - asserted via the combobox chip). Going back must also not
    # re-submit the form.
    #
    # Only back is exercised: programmatic go_forward to a form-submitted (turbo
    # advance) history entry intermittently no-ops in WebDriver, so it can't be
    # asserted reliably. Forward to a full page load is covered in the example
    # above (go_back to "/", then go_forward).
    visit "/"
    visit "/search/registrations"
    expect(page).to have_css(".bike-box-item", wait: 10)
    choose("stolenness_all", allow_label_click: true, visible: :all)

    search_color_and_submit("Red")
    expect_results_frame_color("Red", "Blue")
    expect(page).to have_css(".hw-combobox__chip", text: "Red")

    find(".hw-combobox__chip__remover").click
    search_color_and_submit("Blue")
    expect_results_frame_color("Blue", "Red")
    expect(page).to have_css(".hw-combobox__chip", text: "Blue")
    expect(page).to have_no_css(".hw-combobox__chip", text: "Red")

    page.execute_script("window.__submitStarts = 0; document.addEventListener('turbo:submit-start', () => { window.__submitStarts += 1 })")
    page.go_back
    expect(page).to have_current_path(/query_items/, wait: 10)
    expect_results_frame_color("Red", "Blue")
    expect(page).to have_css(".hw-combobox__chip", text: "Red")
    expect(page).to have_no_css(".hw-combobox__chip", text: "Blue")
    expect(page.evaluate_script("window.__submitStarts")).to be <= 1
  end
end
