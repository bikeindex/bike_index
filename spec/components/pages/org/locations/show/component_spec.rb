# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::Locations::Show::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization_with_organization_features, name: "Brakebills", show_on_map:, lock_show_on_map:, enabled_feature_slugs:) }
  let(:show_on_map) { true }
  let(:lock_show_on_map) { false }
  let(:enabled_feature_slugs) { %w[impound_bikes] }
  let!(:location) { FactoryBot.create(:location, :with_address_record, organization:, name: "Main shop") }

  def rendered_component(organization)
    render_in_view_context do
      render(Pages::Org::Locations::Show::Component.new(organization:, current_country_id: Country.united_states_id))
    end
  end

  let(:component) { rendered_component(organization) }

  def cards(component) = component.css("[data-org--locations-target='location']")

  # The template's blank location is in the document too
  def grid_cards(component) = component.css("[data-org--locations-target='grid'] [data-org--locations-target='location']")

  it "renders the saved location, and one blank location in the template for the add button" do
    expect(component).to have_css("h1", text: "Brakebills location settings")
    expect(component).to have_field("Display Brakebills on Bike Index partner map", type: "checkbox", checked: true)
    expect(component).to have_button("Add location")
    expect(component).to have_field("organization_locations_attributes_0_name", with: "Main shop")
    expect(grid_cards(component).length).to eq 1
    expect(component.at_css("input[name='locations_page']")["value"]).to eq "true"

    # org--locations clones this into the grid, swapping __INDEX__ for a distinct one per added location
    template = Nokogiri::HTML.fragment(component.at_css("template").inner_html)
    expect(cards(template).length).to eq 1
    expect(template.css("input[name='organization[locations_attributes][__INDEX__][name]']").length).to eq 1
    expect(template.text).not_to match "Main shop"

    # Every Save submits the one form: the map bar's, the card's, the bottom
    expect(component.css("form").length).to eq 1
    expect(component.css("button[type=submit]").length).to be >= 2
  end

  context "without locations" do
    let!(:location) { nil }

    it "renders a blank new location" do
      expect(grid_cards(component).length).to eq 1
      expect(grid_cards(component).first["data-new-record"]).to eq "true"
      expect(Location.where(organization_id: organization.id).count).to eq 0
    end
  end

  context "with the map setting locked" do
    let(:lock_show_on_map) { true }

    it "doesn't offer the map checkbox" do
      expect(component).to have_no_field("organization_show_on_map")
      expect(component).to have_button("Add location")
    end
  end
end
