# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Marketplace infinite scroll", :js, type: :system do
  let(:seller) { FactoryBot.create(:user, :with_address_record) }
  let(:paid_seller) { FactoryBot.create(:user, :with_address_record) }
  let!(:membership) { FactoryBot.create(:membership, user: paid_seller) }
  let!(:manufacturer1) { FactoryBot.create(:manufacturer, name: "Yuba", id: 1003, frame_maker: true) }
  let!(:manufacturer2) { FactoryBot.create(:manufacturer, name: "Salsa", id: 764, frame_maker: true) }
  let!(:primary_activity) { FactoryBot.create(:primary_activity, name: "Mountain biking") }
  let!(:other_primary_activity) { FactoryBot.create(:primary_activity, name: "Road cycling") }
  let!(:promoted_listings) do
    # Two Salsa listings (priced under $1300) from a seller with an active membership.
    # Their bikes get a distinct, sequence-named primary_activity, so they never match
    # the "Mountain biking"/"Road cycling" filters used below.
    Array.new(2) do |i|
      item = FactoryBot.create(:bike, :with_primary_activity, manufacturer: manufacturer2)
      listing = FactoryBot.create(:marketplace_listing, :for_sale,
        address_record: paid_seller.address_record, seller: paid_seller, item:,
        amount_cents: 500_00 + 100_00 * i)
      listing.update(published_at: Time.current + (i + 1).minutes)
      listing
    end
  end

  before do
    # Create enough listings to span multiple pages (12 per page)

    15.times do |i|
      item = FactoryBot.create(:bike,
        manufacturer: (i % 2 == 0) ? manufacturer1 : manufacturer2,
        primary_activity: (i < 6) ? primary_activity : other_primary_activity)
      listing = FactoryBot.create(:marketplace_listing, :for_sale,
        address_record: seller.address_record,
        seller:,
        item:,
        amount_cents: 100_00 * i)
      listing.update(published_at: Time.current - i.seconds)
    end
    # Load manufacturers into autocomplete Redis so the local API returns results.
    # Clear first: the autocomplete cache is shared across :js examples and never
    # invalidated by load_all, so a stale cache from an earlier spec can hide this
    # example's manufacturers behind the synthetic free-text option.
    Autocomplete::Loader.clear_redis
    Autocomplete::Loader.load_all(%w[Manufacturer])
  end

  def scroll_to_lazy_load
    # Scroll the lazy-loading frame into view to trigger its IntersectionObserver.
    # Use an instant scroll (not "smooth") so the observer fires deterministically
    # in headless Chrome; the waiting `have_css` assertions that follow then hold
    # until the frame's in-flight fetch completes, so no manual sleep is needed.
    page.execute_script(<<~JS)
      const lazyFrame = document.querySelector('turbo-frame#page_2[loading="lazy"]');
      if (lazyFrame) {
        lazyFrame.scrollIntoView({ block: "end" });
      }
    JS
  end

  def visible_bike_ids
    page.all("[data-test-id^='vehicle-thumbnail-linkspan-']").map { |el| el["data-test-id"].split("-").last.to_i }
  end

  # Reach the marketplace the way a user does: from the homepage, click the
  # "Marketplace" nav link. The nav renders it twice (responsive mobile + desktop
  # copies); only one shows at a time, so match the first.
  def visit_marketplace_via_nav
    # Widen to a desktop viewport so the nav links show inline instead of behind
    # the mobile hamburger menu.
    page.current_window.resize_to(1280, 900)
    visit "/"
    click_link "Marketplace", exact: true, match: :first
  end

  # Filter by a primary activity through the combobox: type its name, click the
  # matching option, then submit. Works whether the combobox starts empty or
  # already has a selection (set replaces the existing text).
  def search_primary_activity(display_name)
    # Each call follows a page load, and a combobox typed into before its controller connects
    # swallows the first character
    wait_for_stimulus
    type_into("#primary_activity", display_name)
    expect(page).to have_css(".hw-combobox__option", text: display_name, wait: 5)
    click_combobox_option(display_name)
    find("#search-button").click
  end

  # Hold back the unfiltered results the frame eager-loads on arrival. Returns the
  # release, so the example decides when they land rather than racing a timer.
  def hold_initial_results_load
    held = Queue.new
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.route("**/search/marketplace*", ->(route, request) {
        # Pushing the token back leaves the gate open, so a later unfiltered
        # request doesn't hang on the drained queue.
        held.push(held.pop) if request.headers["turbo-frame"] == "marketplace_results_frame" &&
          !request.url.include?("primary_activity=")
        route.continue
      })
    end
    -> { held.push(:release) }
  end

  # defaultPrevented read inside the listener only reports preventDefault from listeners
  # that already ran, so the verdict would turn on registration order - which a Stimulus
  # reconnect silently inverts. The next tick has heard from everyone.
  def watch_for_superseded_results
    page.execute_script(<<~JS)
      document.addEventListener("turbo:before-fetch-response", (event) => {
        if (event.target?.id !== "marketplace_results_frame") return

        setTimeout(() => {
          document.body.dataset.testSupersededResultsRejected = event.defaultPrevented ? "true" : "false"
        })
      })
    JS
  end

  # turbo:load fires whenever a page's Turbo visit finishes, which on a loaded runner
  # is after the rider has searched. Force that ordering rather than wait for CI to
  # produce it: between a frame navigation's response and Turbo advancing the address
  # bar to it, the frame leads the URL, and search--form must not reconcile it back.
  # Watching only the first src change keeps a run that never opens that window from
  # firing turbo:load somewhere later in the example instead.
  def dispatch_turbo_load_once_frame_leads_url
    page.execute_script(<<~JS)
      const frame = document.getElementById("marketplace_results_frame")
      const observer = new MutationObserver(() => {
        observer.disconnect()
        const frameUrl = new URL(frame.getAttribute("src") || "", window.location.href)
        if (frameUrl.pathname !== window.location.pathname || frameUrl.search === window.location.search) return

        document.dispatchEvent(new CustomEvent("turbo:load", {detail: {timing: {}}}))
      })
      observer.observe(frame, {attributeFilter: ["src"]})
    JS
  end

  it "fills the kind counts on load, and keeps a search made before the results arrive" do
    release_initial_results_load = hold_initial_results_load
    visit_marketplace_via_nav

    # Counts populate from /search/marketplace/counts once the search--kind-select-fields
    # controller connects - no form submit required, and no results either, since the
    # frame is held open here. All 17 listings (15 standard + 2 promoted) are for_sale,
    # so the for_sale count shows (17).
    expect(page).to have_css("[data-count-target='for_sale']", text: "(17)", wait: 10)

    # The counts come from a different controller, so they don't mean search--form -
    # which rejects the superseded response below - is listening yet. Dropping
    # search_no_js is the first thing its connect does.
    expect(page).to have_no_css("#search_no_js", visible: :all, wait: 10)

    dispatch_turbo_load_once_frame_leads_url
    search_primary_activity("Mountain biking")
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 6)

    # The unfiltered results are only now allowed to arrive - they mustn't take over. The
    # wait covers a round trip the release only now starts, for this file's slowest response.
    watch_for_superseded_results
    release_initial_results_load.call
    # Arrival and verdict assert separately so a failure says which happened: no marker at
    # all means the released response never reached the page, ='false' means it did and
    # Turbo was allowed to render it
    expect(page).to have_css("body[data-test-superseded-results-rejected]", wait: 30)
    expect(page).to have_css("body[data-test-superseded-results-rejected='true']")
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", count: 6)
    expect(page).to have_current_path(/primary_activity=#{primary_activity.id}/)
  end

  it "automatically loads the next page when scrolling to bottom, and switches result layouts" do
    expect(manufacturer1.reload.id).to eq 1003 # sanity check - otherwise the search won't work
    expect(manufacturer2.reload.id).to eq 764 # sanity check - otherwise the search won't work
    promoted_bike_ids = promoted_listings.map(&:item_id)
    visit_marketplace_via_nav

    # Page 1 holds the first 12: the 2 members sort first, then standard listings
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 12)
    # The 2 promoted bikes show the member badge and appear above the standard listings
    expect(page).to have_text("Bike Index member")
    expect(visible_bike_ids.first(2)).to match_array(promoted_bike_ids)
    expect_axe_clean
    # Verify the lazy-loading frame for page 2 exists (5 listings remain)
    expect(page).to have_css("turbo-frame#page_2[loading='lazy']", visible: :all)
    # Frame-rendered results are proof of JS, so the no-JS pagination links never
    # render - only the frame's spinner
    expect(page).to have_no_link(exact_text: "2")
    expect(page).to have_text("Loading more...")
    scroll_to_lazy_load
    # All 17 listings now visible (2 promoted + 15 standard); promoted bikes are not duplicated
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 17)
    expect(visible_bike_ids).to match_array(visible_bike_ids.uniq)

    # Change the search filters By adding a max price and submit via pressing enter
    # and verify that infinite scroll still works
    fill_in "price_max_amount", with: "1300"
    find_field("price_max_amount").send_keys(:return)
    # Page 1 holds the first 12 (2 members ≤ $1300 sort first, then standard)
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 12)
    # Verify lazy frame exists
    expect(page).to have_css("turbo-frame#page_2[loading='lazy']", visible: :all)
    scroll_to_lazy_load
    # 2 promoted + 14 standard ≤ $1300 = 16 total
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 16)

    # And then search "Yuba" without price filter
    # Which will return 8 bikes - so the page won't have the ability to scroll. Verify that it works correctly
    # The Salsa promoted listings shouldn't match, so the member badges disappear
    fill_in "price_max_amount", with: ""
    # Scope to the everything-combobox - the primary_activity field is also a combobox
    within("[data-controller~='search--everything-combobox']") do
      type_into(".hw-combobox__input", "Yuba")
      # Wait for the combobox autocomplete to load
      expect(page).to have_css(".hw-combobox__option", text: "Listings made by Yuba", wait: 5)
      click_combobox_option("Listings made by Yuba")
    end
    find("#search-button").click
    # Should load new results
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 8)
    expect(page).not_to have_text("Bike Index member")
    # Should NOT have a lazy-loading frame for page 2
    expect(page).not_to have_css("turbo-frame#page_2")

    # Finally, clear the Yuba filter the way a user would - by removing its
    # combobox chip - then filter by the "Mountain biking" primary activity
    within("[data-controller~='search--everything-combobox']") do
      find("[aria-label='Remove Yuba']").click
    end
    search_primary_activity("Mountain biking")
    # 6 of the 15 listings have the "Mountain biking" primary activity (a count of
    # 6 also confirms Yuba was cleared - otherwise the two filters would intersect)
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 6)
    # Only 6 results, so there's nothing to lazy-load on a second page
    expect(page).not_to have_css("turbo-frame#page_2")
    # The selection persists after the search - the hidden field carries the id,
    # the visible input shows the display name
    expect(find("#primary_activity-hw-hidden-field", visible: false).value).to eq primary_activity.id.to_s
    expect(find("#primary_activity").value).to eq "Mountain biking"

    # Switching to the list layout re-runs the search rather than dropping its filters
    choose("search_result_view_bike_box", allow_label_click: true)
    expect(page).to have_css(".bike-box-item", wait: 10, count: 6)
    expect(page).to have_no_css("[data-test-id^='vehicle-thumbnail-linkspan-']")
    expect(page).to have_current_path(/search_result_view=bike_box/)
    expect(page).to have_current_path(/primary_activity=#{primary_activity.id}/)

    choose("search_result_view_thumbnail", allow_label_click: true)
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 6)
    expect(page).to have_no_css(".bike-box-item")
  end

  # search_no_js reaches riders who do have JS: Search::RegistrationsController
  # forwards it on the marketplace redirect, and it survives in any URL shared
  # before search--form strips the hidden field. Those renders can't tell, so they
  # ship both paginations and search--pagination-fallback picks.
  it "hands a search_no_js render back to infinite scroll, except on the last page" do
    page.current_window.resize_to(1280, 900)
    visit "/search/marketplace?search_no_js=true"
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 12)

    # The links a rider without JS would have used are gone, the frame's spinner shows
    expect(page).to have_no_link(exact_text: "2")
    expect(page).to have_text("Loading more...")
    scroll_to_lazy_load
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 17)

    # The last page has no frame to scroll into, so its links stay - they're the only
    # way out for a rider who deep-linked here
    visit "/search/marketplace?search_no_js=true&page=2"
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 5)
    expect(page).to have_no_text("Loading more...")
    # Following one navigates the results frame, like registrations search - so page 1
    # comes back in infinite-scroll mode, with no links of its own. Don't count
    # thumbnails here: the click leaves the page scrolled down, so page 2 may already
    # be lazy-loading.
    click_link(exact_text: "1")
    expect(page).to have_css("turbo-frame#page_2[loading='lazy']", visible: :all, wait: 10)
    expect(page).to have_no_link(exact_text: "2")
  end

  # :flaky retry: a programmatic go_forward to a form-submitted (turbo advance)
  # history entry can intermittently no-op in WebDriver (the URL stays on the back
  # entry). It's a harness artifact - a real browser does back/forward reliably -
  # so retry on CI.
  it "keeps results and the primary_activity form in sync across back/forward", :flaky do
    visit_marketplace_via_nav
    # First 12 on the unfiltered page (the 2 members sort first)
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 12)
    # Drop history accumulated by earlier examples so go_back/go_forward operate on
    # this example's own short stack, not a stale foreign entry.
    reset_browser_history

    # Filter by "Mountain biking" (6 listings), then "Road cycling" (9 listings).
    # The two counts differ, so a settled count proves which search the frame holds.
    search_primary_activity("Mountain biking")
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 6)
    expect(find("#primary_activity").value).to eq "Mountain biking"

    search_primary_activity("Road cycling")
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 9)
    expect(find("#primary_activity").value).to eq "Road cycling"

    # Back to the Mountain biking search - results and the combobox reconcile to it
    page.go_back
    expect(page).to have_current_path(/primary_activity=#{primary_activity.id}/, wait: 10)
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 6)
    expect(find("#primary_activity").value).to eq "Mountain biking"
    expect(find("#primary_activity-hw-hidden-field", visible: false).value).to eq primary_activity.id.to_s

    # Forward to the Road cycling search - everything reconciles back to it
    page.go_forward
    expect(page).to have_current_path(/primary_activity=#{other_primary_activity.id}/, wait: 10)
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 9)
    expect(find("#primary_activity").value).to eq "Road cycling"
    expect(find("#primary_activity-hw-hidden-field", visible: false).value).to eq other_primary_activity.id.to_s
  end
end
