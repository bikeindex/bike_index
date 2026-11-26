# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized manage locations", :js, type: :system do
  let(:organization) do
    FactoryBot.create(:organization_with_organization_features, name: "Brakebills", show_on_map: true,
      lock_show_on_map:, enabled_feature_slugs: %w[impound_bikes])
  end
  let(:lock_show_on_map) { false }
  let(:user) { FactoryBot.create(:organization_admin, organization:) }
  let!(:main_shop) { FactoryBot.create(:location, :with_address_record, organization:, name: "Main shop") }
  let!(:south_shop) { FactoryBot.create(:location, :with_address_record, organization:, name: "South shop") }
  let(:map_label) { "Display Brakebills on Bike Index partner map" }

  def location_card(index) = all("[data-org--locations-target='location']")[index]

  def map_bar = find("[data-org--locations-target='mapBar']")

  before do
    sign_in(user)
    visit "/o/#{organization.to_param}/manage/locations"
  end

  it "tracks unsaved changes per card and for the map, then saves them with any Save" do
    expect(page).to have_css("[data-org--locations-target='location']", count: 2)
    expect(page).to have_no_text("Unsaved")

    # Editing a card flags it, and Discard puts the saved value back
    within(location_card(0)) do
      fill_in "Location name", with: "Main shop renamed"
      expect(page).to have_text("This location has unsaved changes")
      expect(page).to have_css("[data-slot='title']", text: "Main shop renamed")
      click_button "Discard"
      expect(page).to have_field("Location name", with: "Main shop")
      expect(page).to have_no_text("Unsaved")

      # A country change swaps the state for a region, and Discard brings the state back
      select "Canada", from: "Country"
      expect(page).to have_field("Region")
      click_button "Discard"
      expect(page).to have_select("Country", selected: "United States")
      expect(page).to have_no_field("Region")
      expect(page).to have_css("input[type=hidden][name$='[region_record_id]'][value='#{main_shop.address_record.region_record_id}']", visible: :all)
      expect(page).to have_no_text("Unsaved")
    end

    # The map setting is flagged in its own bar
    uncheck map_label
    within(map_bar) { expect(page).to have_text("Unsaved") }
    expect(page).to have_text("Unsaved changes to partner map setting")
    expect(location_card(0)).to have_no_field("Publicly visible")
    within(map_bar) { click_button "Discard" }
    expect(page).to have_checked_field(map_label)
    expect(location_card(0)).to have_field("Publicly visible")
    expect(page).to have_no_text("Unsaved")

    # Only one location is the default impound location, and it has to be an impound location
    within(location_card(0)) do
      check "Impound location"
      check "Default impound location"
    end
    within(location_card(1)) do
      check "Impound location"
      expect(page).to have_unchecked_field("Default impound location")
      check "Default impound location"
    end
    expect(location_card(0)).to have_unchecked_field("Default impound location")
    expect(page).to have_text("Unsaved changes to 2 locations")
    within(location_card(1)) do
      uncheck "Impound location"
      expect(page).to have_no_field("Default impound location")
      # Back to what was saved, so there's nothing to discard
      expect(page).to have_no_button("Discard")
    end
    within(location_card(0)) { click_button "Discard" }
    expect(location_card(0)).to have_unchecked_field("Impound location")
    expect(page).to have_no_text("Unsaved")

    # An added location is new until it's discarded, which drops it
    click_button "Add location"
    click_button "Add location"
    expect(page).to have_css("[data-org--locations-target='location']", count: 4)
    # The state combobox's option ids are cloned with the template, and have to stay unique
    ids = all("[id]", visible: :all).map { it[:id] }
    expect(ids.tally.select { |_id, count| count > 1 }).to be_empty
    within(location_card(3)) { click_button "Discard" }
    within(location_card(2)) do
      expect(page).to have_text("New")
      expect(page).to have_field("Location name", with: "Brakebills")
      click_button "Discard"
    end
    expect(page).to have_css("[data-org--locations-target='location']", count: 2)

    # A removed one collapses to a strip, and the last one standing can't be removed
    within(location_card(1)) { click_button "Remove" }
    expect(page).to have_text("South shop will be removed when you save")
    expect(location_card(0)).to have_no_button("Remove")
    click_button "Undo"
    expect(page).to have_no_text("will be removed when you save")
    expect(page).to have_button("Remove", count: 2)

    within(location_card(0)) { fill_in "Location name", with: "Main shop renamed" }
    within(location_card(1)) { click_button "Remove" }
    expect(page).to have_text("Unsaved changes to 2 locations")
    all(:button, "Save").last.click

    expect(page).to have_content("updated successfully")
    expect(organization.reload.locations.pluck(:name)).to eq(["Main shop renamed"])
  end

  context "with the partner map setting locked" do
    let(:lock_show_on_map) { true }

    it "has no map checkbox, and still tracks changes and adds locations" do
      expect(page).to have_no_field(map_label)
      within(location_card(0)) { fill_in "Location name", with: "Main shop renamed" }
      expect(page).to have_text("Unsaved changes to 1 location")
      click_button "Add location"
      expect(page).to have_text("Unsaved changes to 2 locations")
    end
  end
end
