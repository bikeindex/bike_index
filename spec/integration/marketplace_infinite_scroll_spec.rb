# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Marketplace infinite scroll", :js, type: :system do
  let(:seller) { FactoryBot.create(:user, :with_address_record) }
  let(:marketplace_url) { "/search/marketplace" }

  before do
    # Create enough listings to span multiple pages (12 per page)
    15.times do |i|
      item = FactoryBot.create(:bike, :with_primary_activity)
      listing = FactoryBot.create(:marketplace_listing, :for_sale,
        address_record: seller.address_record,
        seller:,
        item:,
        amount_cents: (100 + i) * 100)
      listing.update(published_at: Time.current - i.seconds)
    end
  end

  it "automatically loads the next page when scrolling to bottom" do
    visit marketplace_url

    # Wait for the initial results to load
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 12)

    # Get the initial bike IDs visible on page 1
    initial_bikes = page.all("[data-test-id^='vehicle-thumbnail-linkspan-']").map do |el|
      el["data-test-id"].split("-").last
    end
    expect(initial_bikes.count).to eq(12)

    # Verify the lazy-loading frame for page 2 exists
    expect(page).to have_css("turbo-frame#page_2[loading='lazy']", visible: :all)

    # Scroll the lazy-loading frame into view
    page.execute_script(<<~JS)
      const lazyFrame = document.querySelector('turbo-frame#page_2[loading="lazy"]');
      if (lazyFrame) {
        lazyFrame.scrollIntoView({ behavior: 'smooth', block: 'end' });
      }
    JS

    # Wait a moment for the scroll and IntersectionObserver to trigger
    sleep 1

    # Wait for page 2 to load (3 more items should appear)
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, minimum: 13)

    # Get all bike IDs now visible
    all_bikes = page.all("[data-test-id^='vehicle-thumbnail-linkspan-']").map do |el|
      el["data-test-id"].split("-").last
    end

    # Verify that we have more bikes than initially
    expect(all_bikes.count).to be > initial_bikes.count
  end

  it "does not show loading frame when all results fit on one page" do
    # Remove most listings to have only 5 total (less than 12 per page)
    MarketplaceListing.for_sale.limit(10).each(&:destroy)
    expect(MarketplaceListing.for_sale.count).to eq(5)

    visit marketplace_url

    # Wait for results to load
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 5)

    # Should NOT have a lazy-loading frame for page 2
    expect(page).not_to have_css("turbo-frame#page_2")
  end

  it "maintains infinite scroll after using search filters" do
    visit marketplace_url

    # Wait for initial load
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 12)

    # Change the search filters (e.g., max price) and submit via pressing enter
    fill_in "price_max_amount", with: "500"
    find("#price_max_amount").send_keys(:return)

    # Wait for filtered results to load
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10)

    # Get count of filtered results
    filtered_count = page.all("[data-test-id^='vehicle-thumbnail-linkspan-']").count

    # If there are 12 or more filtered results, verify lazy loading still works
    if filtered_count >= 12
      # Verify lazy frame exists
      expect(page).to have_css("turbo-frame#page_2[loading='lazy']", visible: :all)

      # Scroll the lazy-loading frame into view
      page.execute_script(<<~JS)
        const lazyFrame = document.querySelector('turbo-frame#page_2[loading="lazy"]');
        if (lazyFrame) {
          lazyFrame.scrollIntoView({ behavior: 'smooth', block: 'end' });
        }
      JS

      sleep 1

      # Should load more results
      expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, minimum: filtered_count + 1)
    end
  end
end
