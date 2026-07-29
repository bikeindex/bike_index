# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Register flow", :js, type: :system do
  let(:owner_email) { "owner@example.com" }
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Surly") }
  let!(:red) { FactoryBot.create(:color, name: "Red") }
  let!(:blue) { FactoryBot.create(:color, name: "Blue") }
  let!(:green) { FactoryBot.create(:color, name: "Green") }

  before do
    # The manufacturer combobox autocompletes against the redis index
    Autocomplete::Loader.clear_redis
    Autocomplete::Loader.load_all(%w[Manufacturer])
  end

  it "starts a registration, keeps a full details draft across a reload, and completes" do
    visit "/register/new"

    # new creates the registration and lands on its tokenized step 1
    expect(page).to have_current_path(/register\?b_param_token=.+&step=1/, url: true)

    type_into("#b_param_manufacturer_id", "Surly")
    click_combobox_option("Surly")
    fill_in "b_param[owner_email]", with: owner_email
    click_button "Next"

    expect(page).to have_content("Add your bike")
    details_url = page.current_url
    expect(details_url).to match(/register\?b_param_token=.+&step=2/)

    # The browser back button returns to step 1 on the same registration, prefilled
    page.go_back
    expect(page).to have_field("b_param_manufacturer_id", with: "Surly")
    expect(page).to have_field("b_param[owner_email]", with: owner_email)

    # Coming back from step 2 offers starting over - dismissing keeps the registration
    click_button "Start over"
    find("#start-over-modal [aria-label='Close']").click
    click_button "Next"
    expect(page).to have_current_path(details_url, url: true)

    # Confirming abandons it for a blank registration, which has nothing to start over from
    click_link "Back"
    click_button "Start over"
    click_link "Yes, start over"
    expect(page).to have_field("b_param[owner_email]", with: "")
    expect(page).to have_no_button("Start over")

    type_into("#b_param_manufacturer_id", "Surly")
    click_combobox_option("Surly")
    fill_in "b_param[owner_email]", with: owner_email
    click_button "Next"
    expect(page).to have_content("Add your bike")
    details_url = page.current_url

    # Fill every field: text, chip radio, unit select, comboboxes (including the
    # collapsed additional-color rows) and the missing-serial checkbox
    fill_in "bike[frame_model]", with: "Marlin 7"
    fill_in "bike[year]", with: "2023"
    type_into("#bike_primary_frame_color_id", "Red")
    click_combobox_option("Red")
    click_button "+ Add another color"
    type_into("#bike_secondary_frame_color_id", "Blue")
    click_combobox_option("Blue")
    click_button "+ Add another color"
    type_into("#bike_tertiary_frame_color_id", "Green")
    click_combobox_option("Green")
    find("label", text: "M", exact_text: true).click
    select "cm", from: "bike[frame_size_unit]"
    check "Missing serial"
    # readonly rather than disabled, so "unknown" still submits
    expect(page).to have_field("bike[serial_number]", with: "unknown", readonly: true)
    fill_in "bike[bike_sticker]", with: "A 471 829"

    # Nothing submitted yet - the reload restores the whole draft from form-persist
    visit details_url

    expect(page).to have_field("bike[frame_model]", with: "Marlin 7")
    expect(page).to have_field("bike[year]", with: "2023")
    expect(page).to have_field("bike_primary_frame_color_id", with: "Red")
    expect(find("input[name='bike[primary_frame_color_id]']", visible: :all).value).to eq red.id.to_s
    # A restored selection repaints the rich_display overlay, so it keeps its swatch
    expect(page).to have_css("[data-ui--forms--combobox-display-target='overlay']", text: "Red")
    # The restored additional colors reveal their collapsed rows and use up the add button
    expect(page).to have_field("bike_secondary_frame_color_id", with: "Blue")
    expect(page).to have_field("bike_tertiary_frame_color_id", with: "Green")
    expect(page).to have_no_button("+ Add another color")
    expect(find("input[name='bike[frame_size]'][value='m']", visible: :all)).to be_checked
    # A select always has a value, so it restores from the draft rather than the server default
    expect(page).to have_select("bike[frame_size_unit]", selected: "cm")
    # The restored missing serial re-reveals the made-without link
    expect(page).to have_field("bike[serial_number]", with: "unknown", readonly: true)
    expect(page).to have_checked_field("Missing serial")
    expect(page).to have_button("This bike was made without a serial number")
    expect(page).to have_field("bike[bike_sticker]", with: "A 471 829")

    # The modal's made-without confirm mutates fields programmatically - that
    # state survives a reload too
    click_button "This bike was made without a serial number"
    click_button "I'm 100% sure"
    expect(page).to have_checked_field("This bike was made without a serial")

    visit details_url

    expect(page).to have_checked_field("This bike was made without a serial")
    expect(page).to have_no_field("bike[serial_number]") # the serial section stays swapped out

    # Like bikes/new, phone is only asked for once the status calls for it
    expect(page).to have_no_field("bike[phone]")
    type_into("#bike_status", "Stolen")
    click_combobox_option("Stolen")

    # The status the server renders is only a default, so the draft outlives a
    # reload - and the fields it gates reopen with it
    visit details_url

    expect(page).to have_field("bike_status", with: "Stolen")
    expect(find("input[name='bike[status]']", visible: :all).value).to eq "status_stolen"
    fill_in "bike[phone]", with: "(555) 000-0000"

    click_button "Complete Bike Registration"

    expect(page).to have_content("Registration saved")
    expect(page).to have_content("verify your email")
    b_param = BParam.last
    expect(b_param.bike).to include("frame_model" => "Marlin 7", "year" => "2023",
      "primary_frame_color_id" => red.id.to_s, "secondary_frame_color_id" => blue.id.to_s,
      "tertiary_frame_color_id" => green.id.to_s, "frame_size" => "m",
      "serial_number" => "made_without_serial", "phone" => "(555) 000-0000",
      "status" => "status_stolen")
    expect(BikeServices::Register.send(:details_completed?, b_param)).to be_truthy
  end
end
