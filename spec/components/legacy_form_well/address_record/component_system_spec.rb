# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegacyFormWell::AddressRecord::Component, :js, type: :system do
  let(:base_path) { "/rails/view_components/legacy_form_well/address_record/component/" }
  let(:preview_path) { "#{base_path}default" }

  it "renders default preview" do
    FactoryBot.create(:state_california)
    FactoryBot.create(:state_new_york)
    Country.canada
    visit(preview_path)

    expect(page).to have_content "Street address"
    expect(page).to have_select(
      "user[address_record_attributes][country_id]", selected: "United States"
    )
    expect(page).to have_select(
      "user[address_record_attributes][region_record_id]", selected: "State"
    )
    select "California", from: "user[address_record_attributes][region_record_id]"

    # Switching to canada
    select "Canada", from: "user[address_record_attributes][country_id]"
    expect(page).to have_field("user[address_record_attributes][region_string]", type: "text")

    # Switch back to US
    select "United States", from: "user[address_record_attributes][country_id]"
    # California doesn't persist, it override region_string
    expect(page).to have_select(
      "user[address_record_attributes][region_record_id]", selected: "State"
    )
  end

  context "impounded_bike" do
    let(:preview_path) { "#{base_path}impounded_bike" }

    it "renders" do
      FactoryBot.create(:state_california)
      FactoryBot.create(:state_new_york)
      Country.canada
      visit(preview_path)

      expect(page).to have_select(
        "impound_record[address_record_attributes][country_id]", selected: "United States"
      )
      expect(page).to have_select(
        "impound_record[address_record_attributes][region_record_id]", selected: "State"
      )
      select "California", from: "impound_record[address_record_attributes][region_record_id]"

      # Switching to canada
      select "Canada", from: "impound_record[address_record_attributes][country_id]"
      expect(page).to have_field("impound_record[address_record_attributes][region_string]", type: "text")

      # Switch back to US
      select "United States", from: "impound_record[address_record_attributes][country_id]"

      expect(page).to have_css("label", text: "Where was it found?")
      expect(page).to have_field("impound_record_address_record_attributes_street")
      expect(page).to_not have_field("impound_record_address_record_attributes_street_2")
      expect(page).to have_css("input#impound_record_address_record_attributes_street[required]")
    end
  end
end
