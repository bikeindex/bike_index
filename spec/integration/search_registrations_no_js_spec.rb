# frozen_string_literal: true

require "rails_helper"

# Without the :js tag these run on the rack_test driver, which never executes
# JavaScript - exercising the non-JS fallback: the combobox stays hidden behind
# its plain `query`/`serial` text fields, and the `search_no_js` hidden field is
# never stripped, so submitting renders results synchronously instead of into the
# eager turbo frame (whose `src` is never fetched without JS).
RSpec.describe "Registration search without JavaScript", type: :system do
  include_context :geocoder_stubbed_bounding_box
  include_context :geocoder_default_location

  let(:blue) { FactoryBot.create(:color, name: "Blue") }

  let!(:blue_stolen_bike_nyc) { FactoryBot.create(:stolen_bike_in_nyc, primary_frame_color: blue) }
  let!(:red_stolen_bike_nyc) { FactoryBot.create(:stolen_bike_in_nyc) }
  let!(:blue_stolen_bike_la) { FactoryBot.create(:stolen_bike_in_los_angeles, primary_frame_color: blue) }
  let!(:non_stolen_bike) { FactoryBot.create(:bike) }

  # type: :system defaults to the selenium driver; force rack_test so no
  # JavaScript runs at all
  before { driven_by(:rack_test) }

  def submit_search
    # The submit button is icon-only (an inline SVG), so it has no accessible name
    # to match on - scope to the form and click it directly
    within("#Search_Form") { find("button[type='submit']").click }
  end

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
