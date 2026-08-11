# frozen_string_literal: true

require "rails_helper"

# The rack_test driver never executes JavaScript, which is what exercises the
# non-JS fallback here: the combobox stays hidden behind
# its plain `query`/`serial` text fields, and the `search_no_js` hidden field is
# never stripped, so submitting renders results synchronously instead of into the
# eager turbo frame (whose `src` is never fetched without JS).
RSpec.describe "Search without JavaScript", type: :system, driver: :rack_test do
  include_context :geocoder_stubbed_bounding_box
  include_context :geocoder_default_location

  def submit_search
    # The submit button is icon-only (an inline SVG), so it has no accessible name
    # to match on - scope to the form and click it directly
    within("#Search_Form") { find("button[type='submit']").click }
  end

  describe "registrations" do
    let(:blue) { FactoryBot.create(:color, name: "Blue") }

    let!(:blue_stolen_bike_nyc) { FactoryBot.create(:stolen_bike_in_nyc, primary_frame_color: blue) }
    let!(:red_stolen_bike_nyc) { FactoryBot.create(:stolen_bike_in_nyc) }
    let!(:blue_stolen_bike_la) { FactoryBot.create(:stolen_bike_in_los_angeles, primary_frame_color: blue) }
    let!(:non_stolen_bike) { FactoryBot.create(:bike) }

    it "renders results server-side and filters via standard form submission" do
      # Reach the search page the way a user does - from the homepage nav. The
      # "Search" link carries stolenness=all (default_bike_search_path), so all
      # registrations start in scope.
      visit "/"
      click_link "Search", exact: true, match: :first

      # Without JS the eager frame's src is never fetched, so the page initially
      # shows the form with the results frame still empty (no results rendered).
      expect(page).to have_css("turbo-frame#search_registrations_results_frame[src]", visible: :all)
      expect(page).to have_no_css(".bike-box-item")

      # The loading spinner ships hidden and is only revealed by JS - so a no-JS
      # user is never stuck staring at a spinner the eager src can never resolve.
      expect(page).to have_css("[data-search-loading]", visible: :hidden)
      expect(page).to have_no_css("[data-search-loading]", visible: true)

      # Submitting renders results synchronously. The nav link pre-selected "all"
      # registrations, so all four bikes match
      submit_search
      expect(page).to have_css(".bike-box-item", count: 4)

      # Narrow to stolen only - the non-stolen bike drops out
      choose "stolenness_stolen", visible: :all
      submit_search
      expect(page).to have_css(".bike-box-item", count: 3)

      # Proximity search around NYC drops the LA bike (outside the stubbed bounding box)
      choose "stolenness_proximity", visible: :all
      fill_in "distance", with: "200"
      fill_in "location", with: "New York, NY"
      submit_search
      expect(page).to have_css(".bike-box-item", count: 2)

      # A serial search across all registrations narrows to the single matching bike
      choose "stolenness_all", visible: :all
      fill_in "serial", with: blue_stolen_bike_nyc.serial_number
      submit_search
      expect(page).to have_css(".bike-box-item", count: 1)
      expect(page).to have_current_path(/search_no_js/)
    end
  end

  describe "marketplace" do
    # 14 for-sale listings - two more than the 12 that fit on a page, so the
    # unfiltered search spans two. The :for_sale trait builds each listing's
    # address_record and copies its coordinates onto the bike, which is what
    # proximity filters on.
    let!(:cheap_listings_nyc) { FactoryBot.create_list(:marketplace_listing, 11, :for_sale, amount_cents: 200_00) }
    let!(:cheap_listing_la) { FactoryBot.create(:marketplace_listing, :for_sale, address_in: :los_angeles, amount_cents: 300_00) }
    let!(:pricey_listings_nyc) { FactoryBot.create_list(:marketplace_listing, 2, :for_sale, amount_cents: 900_00) }

    let(:thumbnail) { "[data-test-id^='vehicle-thumbnail-linkspan-']" }

    it "renders listings server-side, paginates and filters via standard form submission" do
      visit "/"
      click_link "Marketplace", exact: true, match: :first

      # Same eager-frame fallback as registrations: no src fetch, so nothing is
      # rendered until the form is submitted, and the spinner stays hidden.
      expect(page).to have_css("turbo-frame#marketplace_results_frame[src]", visible: :all)
      expect(page).to have_css("[data-search-loading]", visible: :hidden)
      expect(page).to have_no_css(thumbnail)

      # Submitting renders the first page of the 14 for-sale listings synchronously
      submit_search
      expect(page).to have_css(thumbnail, count: 12)

      # The lazy-loading frame that appends page 2 on scroll can't fetch itself
      # without JS, so its spinner stays hidden and the links carry the user instead
      expect(page).to have_css("turbo-frame#page_2", visible: :all)
      expect(page).to have_no_text("Loading more...")
      click_link(exact_text: "2")
      expect(page).to have_css(thumbnail, count: 2)

      # A max price drops both $900 listings, leaving a single page - so the
      # pagination links go away
      fill_in "price_max_amount", with: "500"
      submit_search
      expect(page).to have_css(thumbnail, count: 12)
      expect(page).to have_no_link(exact_text: "2")

      # Proximity around NYC drops the LA listing. The price filter is re-rendered
      # into the form, so it still applies.
      choose "marketplace_scope_for_sale_proximity", visible: :all
      fill_in "distance", with: "200"
      fill_in "location", with: "New York, NY"
      submit_search
      expect(page).to have_css(thumbnail, count: 11)
      expect(page).to have_current_path(/search_no_js/)
    end
  end
end
