# frozen_string_literal: true

require "rails_helper"

RSpec.describe "E-bike rules", :js, type: :system do
  before { serve_bikebook_catalog }

  it "checks a Bike Book model or one entered by hand as each is chosen, keeping it in the URL" do
    visit ebike_rules_path
    history_length = page.evaluate_script("history.length")
    wait_for_stimulus("ebike-rules--lookup")
    expect(page).to have_no_text("Throttle top speed")
    # answering a detail with no check to run yet leaves the prompt for a state
    choose("throttle", option: "1", allow_label_click: true)
    expect(page).to have_text("Throttle top speed")
      .and have_css("p", text: "Choose your state.")
    choose("throttle", option: "0", allow_label_click: true)
    expect(page).to have_no_text("Throttle top speed")
    type_into(find_field("Bike model", disabled: false, wait: 10), "haul")
    # US models alone, so not its Canadian one of the same name
    expect(page).to have_css("[role='option']", count: 1)
    retry_on_detach { find("[role='option']", text: "Specialized Haul ST").click }
    # with no state to check it against yet, it waits in the URL
    expect(page).to have_current_path("/ebike-rules?vehicle_models=m/specialized/2025/haul_st")
    expect(page).to have_no_css("[role='status']")
    # its details don't
    expect(page).to have_checked_field("top_speed", with: "28", visible: :all).and have_field("Motor wattage (W)", with: "700", visible: :all)

    # the bike comes along to the state's page, checked against it
    wait_for_stimulus("ebike-rules--lookup")
    type_into(find_field("State"), "Colorado")
    retry_on_detach { find("[role='option']", text: "Colorado").click }
    expect(page).to have_css("[role='status']",
      text: "The Specialized Haul ST is a Class 3 e-bike in Colorado, and is also a Class 2 e-bike with its optional throttle.")
    # a String path matches escaped slashes too, which Turbo writes into history for a frame's URL
    expect(page).to have_current_path(%r{\A/ebike-rules/US/CO\?vehicle_models=m/specialized/2025/haul_st\z})
    expect(page).to have_title("Colorado e-bike laws")
    expect(find_field("Bike model", disabled: false, wait: 10).value).to eq "Specialized Haul ST"
    find("[role='button']", text: "Colorado E-bike rules").click
    expect(page).to have_css("li", text: "Class 3 riders must be 16 or older")

    # the model's details fill the panel, named for it and collapsed until asked for
    expect(page).to have_no_field("Motor wattage (W)")
    click_button "Select custom values"
    expect(page).to have_css("legend", text: "Specialized Haul ST details")
      .and have_checked_field("top_speed", with: "28", visible: :all)
      .and have_checked_field("throttle", with: "1", visible: :all)
      .and have_checked_field("throttle_speed", with: "20", visible: :all)
      .and have_field("Motor wattage (W)", with: "700")
    expect(page).to have_text("Throttle top speed")

    # changing one clears the model, checking the details on their own
    fill_in "Motor wattage (W)", with: "1000"
    find_field("Motor wattage (W)").send_keys(:enter)
    expect(page).to have_css("[role='status']", text: "This isn't an e-bike under current Colorado rules.")
    expect(page).to have_css("legend", exact_text: "Your bike's details").and have_field("Bike model", with: "")
      .and have_field("Motor wattage (W)", with: "1000").and have_no_button("Select custom values")
    details_query = "manual=1&throttle=1&throttle_speed=20&top_speed=28&watts=1000"
    expect(page).to have_current_path("/ebike-rules/US/CO?#{details_query}")

    wait_for_stimulus("ebike-rules--lookup")
    type_into(find_field("State"), "New York")
    retry_on_detach { find("[role='option']", text: "New York").click }
    expect(page).to have_css("[role='status']", text: "This isn't an e-bike under current New York rules.")
    expect(page).to have_current_path("/ebike-rules/US/NY?#{details_query}")
    expect(page).to have_title("New York e-bike laws")
    # New York doesn't use the three classes, so its own replace them
    expect(page).to have_css("#ebike-rules-classes h2", text: "New York e-bike classes")
    expect(page).to have_css("#ebike-rules-classes h3", text: "Bicycle With Electric Assist")
      .and have_no_css("#ebike-rules-classes h3", text: "Class 1")

    # each check replaced the URL, adding nothing to the history
    expect(page.evaluate_script("history.length")).to eq history_length

    type_into(find_field("State"), "Colorado")
    retry_on_detach { find("[role='option']", text: "Colorado").click }
    expect(page).to have_css("[role='status']", text: "This isn't an e-bike under current Colorado rules.")
    expect(page).to have_css("#ebike-rules-classes h2", text: "E-bike classes, explained")
    expect(page).to have_current_path("/ebike-rules/US/CO?#{details_query}")

    # picking it again checks it, and its own details replace them
    type_into(find_field("Bike model"), "haul")
    retry_on_detach { find("[role='option']", text: "Specialized Haul ST").click }
    expect(page).to have_css("[role='status']", text: "The Specialized Haul ST is a Class 3 e-bike in Colorado")
    expect(page).to have_current_path("/ebike-rules/US/CO?vehicle_models=m/specialized/2025/haul_st")
    expect(page).to have_field("Motor wattage (W)", with: "700", visible: :all).and have_button("Select custom values")
      .and have_no_field("Motor wattage (W)")

    # clearing the model clears its details and its check
    find("[data-ebike-rules--lookup-target='comboboxSlot'] .hw-combobox__handle").click
    expect(page).to have_current_path("/ebike-rules/US/CO")
    expect(page).to have_no_css("[role='status']")
    expect(page).to have_field("Motor wattage (W)", with: "").and have_no_checked_field("top_speed", visible: :all)
      .and have_css("legend", text: "Your bike's details")
    find_field("Bike model").send_keys(:escape)

    # details alone are a check once they have a top speed
    find("label", text: "20 mph").click
    expect(page).to have_css("[role='status']", text: "This e-bike is a Class 1 e-bike in Colorado.")
    expect(page).to have_current_path("/ebike-rules/US/CO?manual=1&top_speed=20")

    # the link under the class cards opens the state's e-bike law, in the URL apart from them
    visit "/ebike-rules/US/CA?manual=1&top_speed=28&throttle=1"
    wait_for_stimulus("ebike-rules--classification-toggle")
    state_rules = "#ebike-rules-classes [data-ui--collapse-target='content']"
    expect(page).to have_no_css("#{state_rules} h3", text: "Rider rules")
    find("[role='button']", text: "California E-bike rules").click
    expect(page).to have_css("#{state_rules} h3", text: "Rider rules")
    expect(page).to have_current_path("/ebike-rules/US/CA?manual=1&top_speed=28&throttle=1&state_rules=1")

    # the state's non-e-bike rules take its place, one open at a time, with a toggle for each classification
    find("[role='button']", text: "California non-e-bike rules").click
    expect(page).to have_css("#{state_rules} h3", exact_text: "Moped")
      .and have_no_css("#{state_rules} h3", exact_text: "Electric Bicycle")
    expect(page).to have_current_path(/state_rules=0&non_e_bike_rules=1\z/)
    find("#{state_rules} label", text: "Off-Highway Electric Motorcycle").click
    expect(page).to have_css("#{state_rules} h3", exact_text: "Off-Highway Electric Motorcycle")
      .and have_no_css("#{state_rules} h3", exact_text: "Moped")
    expect(page).to have_current_path(/non_e_bike_rules=1&non_e_bike_type=off_highway_electric_motorcycle\z/)
    find("[role='button']", text: "California E-bike rules").click
    expect(page).to have_css("#{state_rules} h3", exact_text: "Electric Bicycle")
      .and have_no_css("#{state_rules} h3", exact_text: "Off-Highway Electric Motorcycle")
    expect(page).to have_current_path(/state_rules=1&non_e_bike_rules=0/)

    # the alert's link opens them on the classification it falls under, and scrolls to them
    expect(page).to have_css("[role='status']", text: "In California, it may fall under Moped.")
    click_link "Moped rules"
    expect(page).to have_css("#{state_rules} h3", exact_text: "Moped")
      .and have_no_css("#{state_rules} h3", exact_text: "Off-Highway Electric Motorcycle")
      .and have_no_css("#{state_rules} h3", exact_text: "Electric Bicycle")
    expect(page).to have_current_path(/throttle=1&state_rules=0&non_e_bike_rules=1&non_e_bike_type=moped\z/)
    page.document.synchronize do
      top = page.evaluate_script("document.getElementById('non-e-bike-rules').getBoundingClientRect().top")
      raise Capybara::ExpectationNotMet, "non-e-bike rules at #{top}px" unless top.between?(0, 40)
    end

    # as a link to them does, on the classification it names
    visit "/ebike-rules/US/CA?non_e_bike_rules=1&non_e_bike_type=motor_driven_cycle"
    expect(page).to have_css("#{state_rules} h3", exact_text: "Motor-Driven Cycle")
  end

  it "filters the states, opens the one an old link's anchor names, and checks a bike in each from its rules" do
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
    # its link picks it in the form at the top, rather than loading its page, which would clear the filter
    wait_for_stimulus("ebike-rules--lookup")
    click_link "Check an e-bike in New Jersey"
    expect(page).to have_field("State", with: "New Jersey (NJ)", obscured: false)
    expect(page).to have_current_path("/ebike-rules/US/NJ")
    expect(page).to have_title("New Jersey e-bike laws")
    expect(page).to have_field("Filter states", with: "new")
    expect(page).to have_css("#ebike-rules-classes h2", text: "New Jersey e-bike classes")

    # Canada, from the switch under the state, picks a province to check a bike against, among its models
    click_button "switch country"
    within("#ebike-rules-switch-country") do
      type_into(find_field("Country"), "Canada")
      retry_on_detach { find("[role='option']", text: "Canada").click }
    end
    expect(page).to have_current_path("/ebike-rules/CA")
    expect(page).to have_field("Province or territory", with: "")
    expect(page).to have_css("#ebike-rules-classes h3", text: "Canadian Power-Assisted Bicycle")
      .and have_css("#ebike-rules-classes dd", text: "32 km/h")
    wait_for_stimulus("ebike-rules--lookup")
    type_into(find_field("Province or territory"), "Ontario")
    retry_on_detach { find("[role='option']", text: "Ontario").click }
    expect(page).to have_css("#ebike-rules-classes h2", text: "E-bike laws in Ontario")
    type_into(find_field("Bike model", disabled: false, wait: 10), "haul")
    expect(page).to have_css("[role='option']", count: 1)
    retry_on_detach { find("[role='option']", text: "Specialized Haul ST").click }
    expect(page).to have_css("[role='status']", text: "The Specialized Haul ST is legal to ride in Ontario under the Power-Assisted Bicycle rules.")
    expect(page).to have_current_path("/ebike-rules/CA/ON?vehicle_models=m/specialized/2025/haul_st_ca")
    expect(page).to have_title("Ontario e-bike laws")
    expect(page).to have_checked_field("top_speed", with: "32", visible: :all).and have_field("Motor wattage (W)", with: "500", visible: :all)

    # clearing the province leaves the bike waiting on Canada's page
    find("[data-ebike-rules--lookup-target='state'] .hw-combobox__handle").click
    expect(page).to have_current_path("/ebike-rules/CA?vehicle_models=m/specialized/2025/haul_st_ca")
    expect(page).to have_no_css("[role='status']")
    expect(page).to have_css("#ebike-rules-classes h2", text: "E-bike laws in Canada")
  end
end
