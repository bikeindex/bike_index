# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Editing a registration", :js, type: :system do
  let(:owner) { FactoryBot.create(:user_confirmed, name: "Owner McOwnerface") }
  let(:new_owner_email) { "newowner@example.com" }

  let!(:surly) { FactoryBot.create(:manufacturer, name: "Surly") }
  let!(:trek) { FactoryBot.create(:manufacturer, name: "Trek") }
  let!(:black) { Color.black }
  let!(:blue) { FactoryBot.create(:color, name: "Blue") }
  let!(:wheel_700c) { FactoryBot.create(:wheel_size, iso_bsd: 622, name: "700c") }
  let!(:wheel_26) { FactoryBot.create(:wheel_size, iso_bsd: 559, name: "26in") }
  let!(:front_gear_fixed) { FrontGearType.fixed }
  let!(:front_gear_double) { FactoryBot.create(:front_gear_type, name: "Double", count: 2, standard: true) }
  let!(:front_gear_pinion) { FactoryBot.create(:front_gear_type, name: "12 Speed Pinion Gearbox", count: 12, internal: true) }
  let!(:rear_gear_fixed) { RearGearType.fixed }
  let!(:rear_gear_nine) { FactoryBot.create(:rear_gear_type, name: "Nine speed", count: 9, standard: true) }
  let!(:ctype_saddle) { FactoryBot.create(:ctype, name: "Saddle") }
  let!(:ctype_fork) { FactoryBot.create(:ctype, name: "Fork") }
  let!(:primary_activity) { FactoryBot.create(:primary_activity, name: "Road cycling") }
  let!(:organization) { FactoryBot.create(:organization, name: "Community Bike Shop") }

  before do
    Manufacturer.other
    Ctype.other
    Autocomplete::Loader.clear_redis
    Autocomplete::Loader.load_all(%w[Manufacturer])
  end

  def selectize_for(field_id)
    find("##{field_id}", visible: :all).find(:xpath, "./following-sibling::div[contains(@class, 'selectize-control')][1]")
  end

  def pick_selectize(field_id, text)
    pick_within_selectize(selectize_for(field_id), text)
  end

  # Picks an option from a selectize control found within the given scope element
  def pick_within_selectize(control, text)
    control.find(".selectize-input").click
    control.find(".selectize-dropdown-content .option", text: text, wait: 5).click
  end

  # Types into a remote-autocomplete selectize (manufacturer fields) and picks the match.
  # The option is loaded over AJAX, so allow a longer wait for it to appear.
  def pick_remote_selectize(control, text)
    control.find(".selectize-input").click
    type_into(control.find(".selectize-input input"), text)
    control.find(".selectize-dropdown-content .option", text:, wait: 10).click
  end

  def save_bike
    find(".edit-form-well-submit-wrapper input[type=submit]").click
    expect(page).to have_content("Bike successfully updated!", wait: 10)
  end

  # Success alerts are fixed-position and overlay the edit menu, so dismiss them
  # before navigating to the next section
  def click_edit_nav(text)
    all(".primary-alert-block .alert .close").each(&:click)
    expect(page).to have_no_css(".primary-alert-block .alert", wait: 5)
    click_link text
  end

  it "registers a bike then edits every section of the registration" do
    # The registration nav below uses the mobile hamburger, shown only below the
    # lg breakpoint; the Playwright driver defaults to desktop width, so narrow it.
    page.current_window.resize_to(720, 2000)

    # Sign in
    visit new_session_path
    fill_in "Email", with: owner.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
    expect(page).to have_content("Logged in", wait: 5)

    # Dismiss the donation modal that greets logged-in users so it doesn't cover the nav
    find("#donationModal .close").click
    expect(page).to have_no_css("#donationModal.in", wait: 5)

    # Navigate to registration through the menus, then register a bike to the
    # logged in user (owner_email defaults to their email)
    find("#primary_nav_hamburgler").click
    click_link "Register a new bike"
    click_link "Register bike"
    fill_in "Serial number", with: "SERIAL-ORIGINAL-1"
    pick_remote_selectize(selectize_for("bike_manufacturer_id"), "Surly")
    pick_selectize("bike_primary_frame_color_id", "Black")
    click_button "Register"
    expect(page).to have_content("Bike successfully added to the index!", wait: 10)

    bike = Bike.reorder(:created_at).last
    expect(bike.owner_email).to eq owner.email
    expect(bike.current_ownership.claimed?).to be_truthy
    expect(bike.manufacturer).to eq surly

    # ---- Details: fill every available field ----
    pick_selectize("bike_year", "2020")
    fill_in "Frame model", with: "Cross-Check"
    find("#add-secondary").click
    # Revealing the field slides it down and clears its selectize value, so wait for
    # that to settle before picking, otherwise the pick can be erased
    expect(page).to have_css("#secondary-color.unhidden", wait: 5)
    pick_selectize("bike_secondary_frame_color_id", "Blue")
    pick_selectize("bike_frame_material", "Steel")
    within(".ordinal-sizes") { find("label.btn", text: "M").click }
    fill_in "Bike Name", with: "My commuter"
    pick_selectize("bike_primary_activity_id", "Road cycling")
    fill_in "General description", with: "A trusty steel commuter"
    fill_in "Other serial or registration number", with: "EXTRA-REG-42"
    save_bike

    bike.reload
    expect(bike.year).to eq 2020
    expect(bike.frame_model).to eq "Cross-Check"
    expect(bike.primary_frame_color).to eq black
    expect(bike.secondary_frame_color).to eq blue
    expect(bike.frame_material).to eq "steel"
    expect(bike.frame_size).to eq "m"
    expect(bike.name).to eq "My commuter"
    expect(bike.primary_activity).to eq primary_activity
    expect(bike.description).to eq "A trusty steel commuter"
    expect(bike.extra_registration_number).to eq "EXTRA-REG-42"

    # ---- Details: serial correction (updates the serial via the modal) ----
    find('[data-target="#serial-correction"]').click
    expect(page).to have_css("#serial-correction.in", wait: 5)
    within("#serial-correction") do
      fill_in "serial_update_serial", with: "SERIAL-UPDATED-9"
      fill_in "serial_update_reason", with: "Read the frame more carefully"
      click_button "Submit update"
    end
    expect(page).to have_content("SERIAL-UPDATED-9", wait: 10)
    expect(bike.reload.serial_number).to eq "SERIAL-UPDATED-9"

    # ---- Details: manufacturer correction ----
    find('[data-target="#manufacturer-correction"]').click
    expect(page).to have_css("#manufacturer-correction.in", wait: 5)
    within("#manufacturer-correction") do
      pick_remote_selectize(selectize_for("manufacturer_update_manufacturer"), "Trek")
      fill_in "manufacturer_update_reason", with: "It is actually a Trek"
      click_button "Submit update"
    end
    expect(page).to have_content("Trek", wait: 10)
    expect(bike.reload.manufacturer).to eq trek

    # ---- Wheels and Drivetrain ----
    click_edit_nav "Wheels and Drivetrain"
    pick_within_selectize(find("#front_standard .selectize-control"), "700c")
    pick_within_selectize(find("#rear_standard .selectize-control"), "26in")
    choose("bike_front_tire_narrow_true")
    choose("bike_rear_tire_narrow_false")
    check("bike_coaster_brake")
    check("bike_belt_drive")
    # Pinion Gearboxes are internal-only: selecting one checks and disables "Internal front gears"
    pick_selectize("front_gear_select", "12 Speed Pinion Gearbox")
    internal_front_check = find("#front_gear_select_internal")
    expect(internal_front_check).to be_checked
    expect(internal_front_check).to be_disabled
    # Switching to a standard front gear re-enables the checkbox
    pick_selectize("front_gear_select", "Double")
    expect(internal_front_check).not_to be_disabled
    uncheck "Internal front gears"
    pick_selectize("rear_gear_select", "Nine speed")
    save_bike

    bike.reload
    expect(bike.front_wheel_size).to eq wheel_700c
    expect(bike.rear_wheel_size).to eq wheel_26
    expect(bike.front_tire_narrow).to be_truthy
    expect(bike.rear_tire_narrow).to be_falsey
    expect(bike.coaster_brake).to be_truthy
    expect(bike.belt_drive).to be_truthy
    expect(bike.front_gear_type).to eq front_gear_double
    expect(bike.rear_gear_type).to eq rear_gear_nine

    # ---- Accessories and Components (add 2 components) ----
    click_edit_nav "Accessories and Components"
    pick_selectize("bike_handlebar_type", "Flat or riser")
    click_link "Add a component"
    click_link "Add a component"
    component_fieldsets = all("fieldset.additional-component")
    expect(component_fieldsets.count).to eq 2
    within(component_fieldsets[0]) do
      pick_within_selectize(find(".fancy-select .selectize-control"), "Saddle")
      fill_in "Part Description", with: "Brooks leather saddle"
      fill_in "Model", with: "B17"
    end
    within(component_fieldsets[1]) do
      pick_within_selectize(find(".fancy-select .selectize-control"), "Fork")
      fill_in "Part Description", with: "Rigid steel fork"
      fill_in "Model", with: "Long Haul"
    end
    save_bike

    bike.reload
    expect(bike.handlebar_type).to eq "flat"
    expect(bike.components.count).to eq 2
    expect(bike.components.map { |c| c.ctype }).to match_array([ctype_saddle, ctype_fork])

    # ---- Groups and Organizations (add an organization) ----
    click_edit_nav "Groups and Organizations"
    pick_within_selectize(find("#additional_organization_fields .selectize-control"), "Community Bike Shop")
    save_bike

    expect(bike.reload.organizations).to include(organization)

    # ---- Transfer ----
    click_edit_nav "Transfer, Hide or Delete"
    fill_in "Owner email", with: new_owner_email
    click_button "Update ownership"
    expect(page).to have_content("Bike successfully updated!", wait: 10)
    expect(page).to have_content("Owned by #{new_owner_email} but it hasn't been claimed yet")

    bike.reload
    expect(bike.owner_email).to eq new_owner_email
    new_ownership = bike.current_ownership
    expect(new_ownership.owner_email).to eq new_owner_email
    expect(new_ownership.claimed?).to be_falsey
    expect(new_ownership.creator_id).to eq owner.id
  end
end
