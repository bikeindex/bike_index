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

    # The browser back button returns to step_1 on the same registration, prefilled
    page.go_back
    expect(page).to have_field("b_param_manufacturer_id", with: "Surly")
    expect(page).to have_field("b_param[owner_email]", with: owner_email)
    click_button "Next"
    expect(page).to have_current_path(details_url, url: true)

    # Fill every field: text, chip radio, comboboxes (including the collapsed
    # additional-color rows) and the missing-serial checkbox
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
    check "Missing serial"
    expect(page).to have_field("bike[serial_number]", with: "unknown")
    fill_in "bike[bike_sticker]", with: "A 471 829"
    fill_in "bike[phone]", with: "(555) 000-0000"

    # Nothing submitted yet - the reload restores the whole draft from form-persist
    visit details_url

    expect(page).to have_field("bike[frame_model]", with: "Marlin 7")
    expect(page).to have_field("bike[year]", with: "2023")
    expect(page).to have_field("bike_primary_frame_color_id", with: "Red")
    expect(find("input[name='bike[primary_frame_color_id]']", visible: :all).value).to eq red.id.to_s
    # The restored additional colors reveal their collapsed rows and use up the add button
    expect(page).to have_field("bike_secondary_frame_color_id", with: "Blue")
    expect(page).to have_field("bike_tertiary_frame_color_id", with: "Green")
    expect(page).to have_no_button("+ Add another color")
    expect(find("input[name='bike[frame_size]'][value='m']", visible: :all)).to be_checked
    # The restored missing serial re-reveals the made-without link
    expect(page).to have_field("bike[serial_number]", with: "unknown")
    expect(page).to have_checked_field("Missing serial")
    expect(page).to have_button("This bike was made without a serial number")
    expect(page).to have_field("bike[bike_sticker]", with: "A 471 829")
    expect(page).to have_field("bike[phone]", with: "(555) 000-0000")

    click_button "Complete Bike Registration"

    expect(page).to have_content("Registration complete")
    expect(page).to have_content("verify your email")
    b_param = BParam.last
    expect(b_param.bike).to include("frame_model" => "Marlin 7", "year" => "2023",
      "primary_frame_color_id" => red.id.to_s, "secondary_frame_color_id" => blue.id.to_s,
      "tertiary_frame_color_id" => green.id.to_s, "frame_size" => "m",
      "serial_number" => "unknown", "phone" => "(555) 000-0000")
    expect(b_param.details_completed?).to be_truthy
  end
end
