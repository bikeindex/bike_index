# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Marketplace infinite scroll", :js, type: :system do
  let(:seller) { FactoryBot.create(:user, :with_address_record) }
  let(:marketplace_url) { "/search/marketplace" }
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
    # Scroll the lazy-loading frame into view
    page.execute_script(<<~JS)
      const lazyFrame = document.querySelector('turbo-frame#page_2[loading="lazy"]');
      if (lazyFrame) {
        lazyFrame.scrollIntoView({ behavior: 'smooth', block: 'end' });
      }
    JS

    # Wait a moment for the scroll and IntersectionObserver to trigger
    sleep 1
  end

  def bike_show_links
    page.all(:link, href: %r{/bikes/\d+\z})
  end

  it "automatically loads the next page when scrolling to bottom", :flaky do
    expect(manufacturer1.reload.id).to eq 1003 # sanity check - otherwise the search won't work
    expect(manufacturer2.reload.id).to eq 764 # sanity check - otherwise the search won't work
    visit marketplace_url

    # Wait for the initial results to load
    expect(page).to have_link(href: %r{/bikes/\d+\z}, count: 12, wait: 10)
    expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)
    initial_bikes = bike_show_links.map { |a| a[:href][%r{/bikes/(\d+)}, 1] }
    # Verify the lazy-loading frame for page 2 exists
    expect(page).to have_css("turbo-frame#page_2[loading='lazy']", visible: :all)
    scroll_to_lazy_load
    # Wait for page 2 to load (3 more items should appear)
    expect(page).to have_link(href: %r{/bikes/\d+\z}, minimum: 13, wait: 10)
    # Verify that we have more bikes than initially
    expect(bike_show_links.count).to be > initial_bikes.count

    # Change the search filters By adding a max price and submit via pressing enter
    # and verify that infinite scroll still works
    fill_in "price_max_amount", with: "1300"
    find_field("price_max_amount").send_keys(:return)
    # Wait for filtered results to load
    expect(page).to have_link(href: %r{/bikes/\d+\z}, count: 12, wait: 10)
    # Verify lazy frame exists
    expect(page).to have_css("turbo-frame#page_2[loading='lazy']", visible: :all)
    scroll_to_lazy_load
    # Should load more results
    expect(page).to have_link(href: %r{/bikes/\d+\z}, count: 14, wait: 10)

    # And then search "Yuba" without price filter
    # Which will return 8 bikes - so the page won't have the ability to scroll. Verify that it works correctly
    fill_in "price_max_amount", with: ""
    find(".select2-container").click
    find(".select2-search__field").set("Yuba")
    # Wait for select2 to load
    expect(page).to have_content("Listings made by Yuba", wait: 5)
    find(".select2-search__field").send_keys(:enter)
    page.send_keys :return
    # Should load new results
    expect(page).to have_link(href: %r{/bikes/\d+\z}, count: 8, wait: 10)
    # Should NOT have a lazy-loading frame for page 2
    expect(page).not_to have_css("turbo-frame#page_2")
  end
end
