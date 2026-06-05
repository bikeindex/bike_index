# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Marketplace infinite scroll", :js, type: :system do
  let(:seller) { FactoryBot.create(:user, :with_address_record) }
  let!(:manufacturer1) { FactoryBot.create(:manufacturer, name: "Yuba", id: 1003, frame_maker: true) }
  let!(:manufacturer2) { FactoryBot.create(:manufacturer, name: "Salsa", id: 764, frame_maker: true) }

  before do
    # Create enough listings to span multiple pages (12 per page)

    15.times do |i|
      item = FactoryBot.create(:bike, :with_primary_activity,
        manufacturer: (i % 2 == 0) ? manufacturer1 : manufacturer2)
      listing = FactoryBot.create(:marketplace_listing, :for_sale,
        address_record: seller.address_record,
        seller:,
        item:,
        amount_cents: 100_00 * i)
      listing.update(published_at: Time.current - i.seconds)
    end
    # Load manufacturers into autocomplete Redis so the local API returns results
    Autocomplete::Loader.load_all(%w[Manufacturer])
  end

  def scroll_to_lazy_load
    # Scroll the lazy-loading frame into view to trigger its IntersectionObserver.
    # Use an instant scroll (not "smooth") so the observer fires deterministically
    # in headless Chrome; capybara-lockstep then holds the next assertion until the
    # frame's in-flight fetch completes, so no manual sleep is needed.
    page.execute_script(<<~JS)
      const lazyFrame = document.querySelector('turbo-frame#page_2[loading="lazy"]');
      if (lazyFrame) {
        lazyFrame.scrollIntoView({ block: "end" });
      }
    JS
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

  it "loads the kind counts on initial render" do
    visit_marketplace_via_nav

    # Counts populate from /search/marketplace/counts once the search--kind-select-fields
    # controller connects - no form submit required. The eager turbo-frame flow no
    # longer auto-submits on load, so this guards that initial render still fills them.
    # All 15 published listings are for_sale, so the for_sale count shows (15).
    expect(page).to have_css("[data-count-target='for_sale']", text: "(15)", wait: 10)
  end

  it "automatically loads the next page when scrolling to bottom" do
    expect(manufacturer1.reload.id).to eq 1003 # sanity check - otherwise the search won't work
    expect(manufacturer2.reload.id).to eq 764 # sanity check - otherwise the search won't work
    visit_marketplace_via_nav

    # Wait for the initial results to load
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 12)
    expect_axe_clean
    # Get the initial bike IDs visible on page 1
    initial_bikes = page.all("[data-test-id^='vehicle-thumbnail-linkspan-']").map do |el|
      el["data-test-id"].split("-").last
    end
    expect(initial_bikes.count).to eq(12)
    # Verify the lazy-loading frame for page 2 exists
    expect(page).to have_css("turbo-frame#page_2[loading='lazy']", visible: :all)
    scroll_to_lazy_load
    # Wait for page 2 to load (3 more items should appear)
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, minimum: 13)
    # Get all bike IDs now visible
    all_bikes = page.all("[data-test-id^='vehicle-thumbnail-linkspan-']").map do |el|
      el["data-test-id"].split("-").last
    end
    # Verify that we have more bikes than initially
    expect(all_bikes.count).to be > initial_bikes.count

    # Change the search filters By adding a max price and submit via pressing enter
    # and verify that infinite scroll still works
    fill_in "price_max_amount", with: "1300"
    find_field("price_max_amount").send_keys(:return)
    # Wait for filtered results to load
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 12)
    # Verify lazy frame exists
    expect(page).to have_css("turbo-frame#page_2[loading='lazy']", visible: :all)
    scroll_to_lazy_load
    # Should load more results
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 14)

    # And then search "Yuba" without price filter
    # Which will return 8 bikes - so the page won't have the ability to scroll. Verify that it works correctly
    fill_in "price_max_amount", with: ""
    find(".hw-combobox__input").set("Yuba")
    # Wait for the combobox autocomplete to load
    expect(page).to have_css(".hw-combobox__option", text: "Listings made by Yuba", wait: 5)
    find(".hw-combobox__option", text: "Listings made by Yuba", match: :first).click
    find("#search-button").click
    # Should load new results
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 8)
    # Should NOT have a lazy-loading frame for page 2
    expect(page).not_to have_css("turbo-frame#page_2")
  end
end
