# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Marketplace infinite scroll", :js, type: :system do
  let(:seller) { FactoryBot.create(:user, :with_address_record) }
  let(:paid_seller) { FactoryBot.create(:user, :with_address_record) }
  let!(:membership) { FactoryBot.create(:membership, user: paid_seller) }
  let(:marketplace_url) { "/search/marketplace" }
  let!(:manufacturer1) { FactoryBot.create(:manufacturer, name: "Yuba", id: 1003, frame_maker: true) }
  let!(:manufacturer2) { FactoryBot.create(:manufacturer, name: "Salsa", id: 764, frame_maker: true) }
  let!(:promoted_listings) do
    # Two Salsa listings (priced under $1300) from a seller with an active membership
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

  def visible_bike_ids
    page.all("[data-test-id^='vehicle-thumbnail-linkspan-']").map { |el| el["data-test-id"].split("-").last.to_i }
  end

  it "automatically loads the next page when scrolling to bottom", :flaky do
    expect(manufacturer1.reload.id).to eq 1003 # sanity check - otherwise the search won't work
    expect(manufacturer2.reload.id).to eq 764 # sanity check - otherwise the search won't work
    promoted_bike_ids = promoted_listings.map(&:item_id)
    visit marketplace_url

    # 2 promoted + 12 standard = 14 thumbnails on page 1
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 14)
    # Member listings header is visible and the 2 promoted bikes appear above the standard listings
    expect(page).to have_css("h2", text: "Bike Index member listings")
    expect(visible_bike_ids.first(2)).to match_array(promoted_bike_ids)
    expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)
    # Verify the lazy-loading frame for page 2 exists (3 standard listings remain)
    expect(page).to have_css("turbo-frame#page_2[loading='lazy']", visible: :all)
    scroll_to_lazy_load
    # All 17 listings now visible (2 promoted + 15 standard); promoted bikes are not duplicated
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 17)
    expect(visible_bike_ids).to match_array(visible_bike_ids.uniq)

    # Change the search filters By adding a max price and submit via pressing enter
    # and verify that infinite scroll still works
    fill_in "price_max_amount", with: "1300"
    find_field("price_max_amount").send_keys(:return)
    # 2 promoted (both ≤ $1300) + 12 standard = 14 on page 1
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 14)
    # Verify lazy frame exists
    expect(page).to have_css("turbo-frame#page_2[loading='lazy']", visible: :all)
    scroll_to_lazy_load
    # 2 promoted + 14 standard ≤ $1300 = 16 total
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 16)

    # And then search "Yuba" without price filter
    # Which will return 8 bikes - so the page won't have the ability to scroll. Verify that it works correctly
    # The Salsa promoted listings shouldn't match, so the member listings section disappears
    fill_in "price_max_amount", with: ""
    find(".hw-combobox__input").set("Yuba")
    # Wait for the combobox autocomplete to load
    expect(page).to have_css(".hw-combobox__option", text: "Listings made by Yuba", wait: 5)
    find(".hw-combobox__option", text: "Listings made by Yuba", match: :first).click
    find("#search-button").click
    # Should load new results
    expect(page).to have_css("[data-test-id^='vehicle-thumbnail-linkspan-']", wait: 10, count: 8)
    expect(page).not_to have_css("h2", text: "Bike Index member listings")
    # Should NOT have a lazy-loading frame for page 2
    expect(page).not_to have_css("turbo-frame#page_2")
  end
end
