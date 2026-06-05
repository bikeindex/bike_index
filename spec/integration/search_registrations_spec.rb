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

  # Reach the search page the way a user does: from the homepage, click the
  # "Search" nav link. Establishing history this way also lets back-nav return to
  # the homepage. The nav renders the link twice (responsive mobile + desktop
  # copies); only one shows at a time, so match the first.
  def visit_search_via_nav
    # Widen to a desktop viewport so the nav links show inline instead of behind
    # the mobile hamburger menu.
    page.current_window.resize_to(1280, 900)
    visit "/"
    click_link "Search", exact: true, match: :first
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
    visit_search_via_nav

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

  it "populates the kind counts after each search and reloads results on back-nav" do
    visit_search_via_nav
    expect(page).to have_css(".bike-box-item", wait: 10)

    # Counts come from /api/v3/search/count, fetched on each form submit
    # (turbo:submit-end -> setKindCounts). Both blue bikes are stolen, so a Blue
    # search fills the "stolen" kind count with (2).
    choose("stolenness_all", allow_label_click: true, visible: :all)
    search_color_and_submit("Blue")
    expect(page).to have_css(".bike-box-item", count: 2, wait: 10)
    expect(page).to have_css("[data-count-target='stolen']", text: "(2)", wait: 10)

    # Searching Red re-fetches: only one red bike is stolen, so the count updates to (1).
    find(".hw-combobox__chip__remover").click
    search_color_and_submit("Red")
    expect(page).to have_css("[data-count-target='stolen']", text: "(1)", wait: 10)

    # Search Blue again, view a result, then return to the Blue results.
    find(".hw-combobox__chip__remover").click
    search_color_and_submit("Blue")
    expect(page).to have_css(".bike-box-item", count: 2, wait: 10)
    click_first_bike_and_go_back

    # Back again to an earlier search. Its results must reload rather than
    # restoring a Turbo snapshot whose frame is stuck in the [busy] loading state
    # (results hidden under the spinner overlay) - the "everything fails after
    # going back from a search" bug.
    page.go_back
    expect(page).to have_css(".bike-box-item", wait: 10)
  end

  # :flaky retry: even on a shallow stack, a programmatic go_forward to a
  # form-submitted (turbo advance) history entry can still intermittently no-op
  # in WebDriver (the URL stays on the back entry). It's a harness artifact - a
  # real browser does back/forward reliably - so retry on CI.
  it "keeps back/forward navigation in sync without double-submitting", :flaky do
    # Search Red, then Blue, then retrace with the browser's back and forward
    # buttons. Each step must leave the frame and form matching the restored URL:
    # the frame is checked by the bikes' colors inside it (both searches return 2
    # bikes, so a bare count wouldn't catch a wrong-color frame), the form by the
    # combobox chip. Back must also not re-submit the form.
    #
    # This guards the end state, not a specific mechanism. Turbo's snapshot
    # restoration keeps the frame correct here on its own - it stays green even
    # with reloadFrameIfUrlStale stubbed out - so this is not a test of that
    # reconciler. reloadFrameIfUrlStale is a fallback for genuinely stale
    # snapshots, invoked on turbo:load (which does fire on these restorations).
    #
    # Run in a fresh window: Capybara never resets browser history between
    # examples, so it accumulates across the suite, and WebDriver back/forward
    # only behave reliably on a shallow stack - a deep one lands go_back/
    # go_forward on a stale entry from an earlier example (the foreign
    # stolenness=stolen URL this used to flake on). A new window starts with
    # empty history, keeping this example's stack short.
    within_window(open_new_window) do
      visit_search_via_nav
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

      # Back to the Red search - frame and form reconcile to Red, no extra submit.
      page.execute_script("window.__submitStarts = 0; document.addEventListener('turbo:submit-start', () => { window.__submitStarts += 1 })")
      page.go_back
      expect(page).to have_current_path(/query_items/, wait: 10)
      expect_results_frame_color("Red", "Blue")
      expect(page).to have_css(".hw-combobox__chip", text: "Red")
      expect(page).to have_no_css(".hw-combobox__chip", text: "Blue")
      expect(page.evaluate_script("window.__submitStarts")).to be <= 1

      # Forward to the Blue search - frame and form reconcile back to Blue.
      page.go_forward
      expect_results_frame_color("Blue", "Red")
      expect(page).to have_css(".hw-combobox__chip", text: "Blue")
      expect(page).to have_no_css(".hw-combobox__chip", text: "Red")
    end
  end
end
