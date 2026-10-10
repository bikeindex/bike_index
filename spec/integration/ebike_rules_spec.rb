# frozen_string_literal: true

require "rails_helper"

RSpec.describe "E-bike rules", :js, type: :system do
  before { serve_bikebook_catalog }

  it "checks a BikeBook model or one entered by hand as each is chosen, keeping it in the URL" do
    visit ebike_rules_path
    type_into(find_field("Bike model", disabled: false, wait: 10), "haul")
    retry_on_detach { find("[role='option']", text: "Specialized Haul ST").click }
    # with no state to check it against yet, it waits in the URL
    expect(page).to have_current_path("/ebike-rules?vehicle_models=m%2Fspecialized%2F2025%2Fhaul_st")
    expect(page).to have_no_css("[role='status']")
    # its details don't
    expect(page).to have_checked_field("top_speed", with: "28", visible: :all).and have_field("Motor wattage (W)", with: "700")

    # the bike comes along to the state's page, checked against it
    wait_for_stimulus("ebike-rules--lookup")
    type_into(find_field("State"), "Colorado")
    retry_on_detach { find("[role='option']", text: "Colorado").click }
    expect(page).to have_css("[role='status']",
      text: "Your Specialized Haul ST is legal to ride in Colorado as a Class 2 and 3 e-bike.")
    expect(page).to have_current_path("/ebike-rules/co?vehicle_models=m%2Fspecialized%2F2025%2Fhaul_st")
    expect(page).to have_title("Colorado e-bike laws")
    expect(find_field("Bike model", disabled: false, wait: 10).value).to eq "Specialized Haul ST"
    find("[role='button']", text: "Read more").click
    expect(page).to have_css("li", text: "Class 3 riders must be 16 or older")

    # the model's details fill the panel, named for it
    expect(page).to have_css("legend", text: "Specialized Haul ST details")
      .and have_checked_field("top_speed", with: "28", visible: :all)
      .and have_checked_field("throttle", with: "1", visible: :all)
      .and have_field("Motor wattage (W)", with: "700")

    # changing one checks the custom details instead, keeping the model
    fill_in "Motor wattage (W)", with: "1000"
    find_field("Motor wattage (W)").send_keys(:enter)
    expect(page).to have_css("[role='status']", text: "This isn't an e-bike under current Colorado rules.")
    expect(page).to have_css("legend", exact_text: "Custom details")
    custom_query = "vehicle_models=m%2Fspecialized%2F2025%2Fhaul_st&manual=1&top_speed=28&throttle=1&watts=1000"
    expect(page).to have_current_path("/ebike-rules/co?#{custom_query}")

    wait_for_stimulus("ebike-rules--lookup")
    type_into(find_field("State"), "New York")
    retry_on_detach { find("[role='option']", text: "New York").click }
    expect(page).to have_css("[role='status']", text: "This isn't an e-bike under current New York rules.")
    expect(page).to have_current_path("/ebike-rules/ny?#{custom_query}")
    expect(page).to have_title("New York e-bike laws")
    # New York doesn't use the three classes, so its own replace them
    expect(page).to have_css("#ebike-rules-classes h2", text: "New York e-bike classes")
    expect(page).to have_css("#ebike-rules-classes h3", text: "Bicycle With Electric Assist")
      .and have_no_css("#ebike-rules-classes h3", text: "Class 1")

    # back returns to Colorado's check, rather than to a snapshot that leaves for New York again
    page.go_back
    expect(page).to have_css("[role='status']", text: "This isn't an e-bike under current Colorado rules.")
    expect(page).to have_field("State", with: "Colorado (CO)")
    expect(page).to have_css("#ebike-rules-classes h2", text: "E-bike classes, explained")
    wait_for_stimulus("ebike-rules--lookup")
    expect(page).to have_current_path("/ebike-rules/co?#{custom_query}")

    # clearing the model leaves its custom details, checked on their own
    clear_bike = -> { find("[data-ebike-rules--lookup-target='comboboxSlot'] .hw-combobox__handle").click }
    find_field("Bike model", disabled: false, wait: 10)
    clear_bike.call
    expect(page).to have_current_path("/ebike-rules/co?manual=1&top_speed=28&throttle=1&watts=1000")
    expect(page).to have_css("[role='status']", text: "This isn't an e-bike under current Colorado rules.")
      .and have_css("legend", exact_text: "Your bike's details")
    find_field("Bike model").send_keys(:escape)

    # picking it again checks it, and its own details replace them
    type_into(find_field("Bike model"), "haul")
    retry_on_detach { find("[role='option']", text: "Specialized Haul ST").click }
    expect(page).to have_css("[role='status']", text: "Your Specialized Haul ST is legal to ride in Colorado")
    expect(page).to have_current_path("/ebike-rules/co?vehicle_models=m%2Fspecialized%2F2025%2Fhaul_st")
    expect(page).to have_field("Motor wattage (W)", with: "700").and have_css("legend", exact_text: "Specialized Haul ST details")

    # clearing the model clears its details and its check
    clear_bike.call
    expect(page).to have_current_path("/ebike-rules/co")
    expect(page).to have_no_css("[role='status']")
    expect(page).to have_field("Motor wattage (W)", with: "").and have_no_checked_field("top_speed", visible: :all)
      .and have_css("legend", text: "Your bike's details")
    find_field("Bike model").send_keys(:escape)

    # details alone are a check once they have a top speed
    find("label", text: "20 mph").click
    expect(page).to have_css("[role='status']", text: "Your e-bike is legal to ride in Colorado as a Class 1 e-bike.")
    expect(page).to have_current_path("/ebike-rules/co?manual=1&top_speed=20")
  end

  it "filters the states, opens the one an old link's anchor names, and links each to its page" do
    visit "#{ebike_rules_path}#state-pa"
    expect(page).to have_css("#state-panel-pa", text: "Its own definition: Pedalcycle With Electric Assist")

    fill_in "Filter states", with: "new"
    expect(page).to have_text("4 of 51 match")
    expect(page).to have_css("[data-name='New Jersey']").and have_no_css("[data-name='California']")

    # the whole row opens its rules, which link to its page
    history_length = page.evaluate_script("history.length")
    find("#state-nj [role='button']").click
    expect(page).to have_css("#state-panel-nj", visible: true)
    # its hash replaces the URL's, without a history entry
    expect(page.evaluate_script("location.hash")).to eq "#state-nj"
    expect(page.evaluate_script("history.length")).to eq history_length
    click_link "Check an e-bike in New Jersey"
    expect(page).to have_current_path("/ebike-rules/nj")
    expect(page).to have_field("State", with: "New Jersey (NJ)")
    expect(page).to have_title("New Jersey e-bike laws")
  end
end
