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
    # Clear first: the autocomplete cache (autc:test:*) lives in a Redis DB shared
    # across :js examples and survives 600s, but load_all never invalidates it. A
    # stale "red"/"blue" cache from an earlier spec makes the combobox return no
    # color match, leaving only the synthetic "Search for X" free-text option -
    # which search_color_and_submit then clicks, turning the search into a text
    # query that matches nothing and renders an empty results frame.
    Autocomplete::Loader.clear_redis
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

  # Clear the browser's back/forward stack. Capybara never resets history between
  # examples, so it accumulates across the suite, and WebDriver back/forward only
  # behave reliably on a shallow stack.
  def reset_browser_history
    page.driver.browser.execute_cdp("Page.resetNavigationHistory")
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

  # flaky: 4 (4 attempts): every Turbo navigation here (form submit, go_back,
  # go_forward) reloads the eager results frame, and under CI load that fetch can
  # intermittently outlast the 10s wait - or a programmatic go_forward to a
  # turbo-advance history entry can no-op in WebDriver (the URL stays on the back
  # entry). Both are harness artifacts a real browser doesn't hit, and they can
  # recur across attempts on a busy runner, so allow more retries than the default.
  it "keeps results, counts, and form in sync across search and back/forward", flaky: 4 do
    # Search Red, then Blue, then retrace with the browser's back and forward
    # buttons. Each step must leave the frame, form, and kind counts matching the
    # restored URL: the frame by the bikes' colors inside it (both searches return
    # 2 bikes, so a bare count wouldn't catch a wrong-color frame), the form by the
    # combobox chip, and the counts by the stolen tally (Red has 1 stolen bike,
    # Blue has 2). Back must also not re-submit the form.
    #
    # This guards the end state, not a specific mechanism. Turbo's snapshot
    # restoration keeps the frame correct here on its own - it stays green even
    # with reloadFrameIfUrlStale stubbed out - so this is not a test of that
    # reconciler. reloadFrameIfUrlStale is a fallback for genuinely stale
    # snapshots, invoked on turbo:load (which does fire on these restorations).
    visit_search_via_nav
    expect(page).to have_css(".bike-box-item", wait: 10)
    # Drop history accumulated by earlier examples so go_back/go_forward below
    # operate on this example's own short stack, not a stale foreign entry (the
    # leftover stolenness=stolen URL this used to flake on).
    reset_browser_history
    choose("stolenness_all", allow_label_click: true, visible: :all)

    # Each search re-fetches the kind counts (turbo:submit-end -> setKindCounts):
    # one red bike is stolen, so the stolen count is (1).
    search_color_and_submit("Red")
    expect_results_frame_color("Red", "Blue")
    expect(page).to have_css(".hw-combobox__chip", text: "Red")
    expect(page).to have_css("[data-count-target='stolen']", text: "(1)", wait: 10)

    # Both blue bikes are stolen, so searching Blue updates the count to (2).
    find(".hw-combobox__chip__remover").click
    search_color_and_submit("Blue")
    expect_results_frame_color("Blue", "Red")
    expect(page).to have_css(".hw-combobox__chip", text: "Blue")
    expect(page).to have_no_css(".hw-combobox__chip", text: "Red")
    expect(page).to have_css("[data-count-target='stolen']", text: "(2)", wait: 10)

    # Back to the Red search - frame, form, and counts reconcile to Red, no extra
    # submit. The count also guards the dedupe marker: restoring the cached
    # snapshot must show this query's counts, not a stale or blank carry-over.
    page.execute_script("window.__submitStarts = 0; document.addEventListener('turbo:submit-start', () => { window.__submitStarts += 1 })")
    page.go_back
    expect(page).to have_current_path(/query_items/, wait: 10)
    expect_results_frame_color("Red", "Blue")
    expect(page).to have_css(".hw-combobox__chip", text: "Red")
    expect(page).to have_no_css(".hw-combobox__chip", text: "Blue")
    expect(page).to have_css("[data-count-target='stolen']", text: "(1)", wait: 10)
    expect(page.evaluate_script("window.__submitStarts")).to be <= 1

    # Forward to the Blue search - frame, form, and counts reconcile back to Blue.
    page.go_forward
    expect_results_frame_color("Blue", "Red")
    expect(page).to have_css(".hw-combobox__chip", text: "Blue")
    expect(page).to have_no_css(".hw-combobox__chip", text: "Red")
    expect(page).to have_css("[data-count-target='stolen']", text: "(2)", wait: 10)

    # Viewing a result and returning must reload the frame, not restore a Turbo
    # snapshot stuck in the [busy] loading state (results hidden under the spinner
    # overlay) - the "everything fails after going back from a search" bug.
    click_first_bike_and_go_back
  end
end
