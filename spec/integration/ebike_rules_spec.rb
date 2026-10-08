# frozen_string_literal: true

require "rails_helper"

RSpec.describe "E-bike rules", :js, type: :system do
  before { serve_bikebook_catalog }

  it "goes to a state's page on choosing it, and checks a Bike Book model then one entered by hand there" do
    visit ebike_rules_path
    find_field("Bike model", disabled: false, wait: 10)
    click_on "Check my bike"
    expect(page).to have_css("[role='alert']", text: "Choose a state.")

    # with no bike picked, it's just the state's page
    wait_for_stimulus("ebike-rules--lookup")
    select "Colorado", from: "State"
    expect(page).to have_current_path("/ebike-rules/co")
    expect(page).to have_title("Colorado e-bike laws")
    expect(page).to have_no_css("[role='alert']")

    type_into(find_field("Bike model", disabled: false, wait: 10), "haul")
    retry_on_detach { find("[role='option']", text: "Specialized Haul ST").click }
    click_on "Check my bike"

    expect(page).to have_css("[role='status']",
      text: "Your Specialized Haul ST is legal to ride in Colorado as a Class 3 e-bike, with 1 rule to check.")
    expect(page).to have_current_path("/ebike-rules/co?bike=m%2Fspecialized%2F2025%2Fhaul_st")
    expect(find_field("Bike model", disabled: false, wait: 10).value).to eq "Specialized Haul ST 2025"

    expect(page).to have_css("li", text: "Class 3 riders must be 16 or older")

    click_on "Can't find your bike? Enter its details."
    expect(page).to have_field("Bike model", disabled: true)
    # only a Class 2 has a throttle by default
    find("label", text: "Class 1").click
    expect(page).to have_checked_field("throttle", with: "0", visible: :all)
    find("label", text: "Class 2").click
    expect(page).to have_checked_field("throttle", with: "1", visible: :all)
    fill_in "Motor wattage (W)", with: "1000"
    click_on "Check my bike"

    expect(page).to have_css("[role='status']", text: "Your e-bike is not permitted as an e-bike under current Colorado rules.")
    expect(page).to have_current_path("/ebike-rules/co?manual=1&e_bike_class=2&watts=1000&throttle=1")

    # the bike comes along to the new state's page, checked against it
    wait_for_stimulus("ebike-rules--lookup")
    select "New York", from: "State"
    expect(page).to have_css("[role='status']", text: "Your e-bike is not permitted as an e-bike under current New York rules.")
    expect(page).to have_current_path("/ebike-rules/ny?manual=1&e_bike_class=2&watts=1000&throttle=1")
    expect(page).to have_title("New York e-bike laws")

    # back returns to Colorado's check, rather than to a snapshot that leaves for New York again
    page.go_back
    expect(page).to have_css("[role='status']", text: "Your e-bike is not permitted as an e-bike under current Colorado rules.")
    expect(page).to have_select("State", selected: "Colorado")
    wait_for_stimulus("ebike-rules--lookup")
    expect(page).to have_current_path("/ebike-rules/co?manual=1&e_bike_class=2&watts=1000&throttle=1")
  end

  it "filters the states, opens the one an old link's anchor names, and links each to its page" do
    visit "#{ebike_rules_path}#state-ny"
    expect(page).to have_css("#state-panel-ny", text: "Its own definition: Bicycle With Electric Assist")

    fill_in "Filter states", with: "new"
    expect(page).to have_text("4 of 51 match")
    expect(page).to have_css("[data-name='New Jersey']").and have_no_css("[data-name='California']")

    click_link "New Jersey"
    expect(page).to have_current_path("/ebike-rules/nj")
    expect(page).to have_select("State", selected: "New Jersey")
    expect(page).to have_title("New Jersey e-bike laws")
  end
end
