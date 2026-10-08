# frozen_string_literal: true

require "rails_helper"

RSpec.describe "E-bike rules", :js, type: :system do
  before { serve_bikebook_catalog }

  it "checks a Bike Book model picked from the search, then one entered by hand" do
    visit ebike_rules_path
    click_on "Check my bike"
    expect(page).to have_css("[role='alert']", text: "Choose a state.")

    select "Colorado", from: "State"
    bike_field = find_field("Bike model", disabled: false, wait: 10)
    type_into(bike_field, "haul")
    retry_on_detach { find("[role='option']", text: "Specialized Haul ST").click }
    click_on "Check my bike"

    expect(page).to have_css("[role='status']",
      text: "Your Specialized Haul ST is legal to ride in Colorado as a Class 3 e-bike, with 1 rule to check.")
    expect(page).to have_current_path("/ebike-rules?state=CO&bike=m%2Fspecialized%2F2025%2Fhaul_st")
    expect(find_field("Bike model", disabled: false, wait: 10).value).to eq "Specialized Haul ST 2025"

    expect(page).to have_css("li", text: "Class 3 riders must be 16 or older")

    click_on "Can't find your bike? Enter its details."
    expect(page).to have_field("Bike model", disabled: true)
    fill_in "Motor wattage (W)", with: "1000"
    click_on "Check my bike"

    expect(page).to have_css("[role='status']", text: "Your e-bike is not permitted as an e-bike under current Colorado rules.")
    expect(page).to have_current_path("/ebike-rules?state=CO&manual=1&e_bike_class=2&watts=1000&throttle=1")
  end

  it "filters the states, and opens the one a link names" do
    visit "#{ebike_rules_path}#state-ny"
    expect(page).to have_css("#state-panel-ny", text: "Its own definition: Bicycle With Electric Assist")

    fill_in "Filter states", with: "new"
    expect(page).to have_text("4 of 51 match")
    expect(page).to have_css("[data-name='New Jersey']").and have_no_css("[data-name='California']")
  end
end
