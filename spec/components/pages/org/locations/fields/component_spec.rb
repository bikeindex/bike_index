# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::Locations::Fields::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization_with_organization_features, name: "Brakebills", show_on_map:, enabled_feature_slugs:) }
  let(:show_on_map) { true }
  let(:enabled_feature_slugs) { %w[impound_bikes] }
  let(:location) { FactoryBot.create(:location, :with_address_record, organization:, name: "Main shop") }

  def rendered_component(organization, location)
    render_in_view_context do
      form_for(organization, url: "/") do |f|
        f.fields_for(:locations, location) do |builder|
          render(Pages::Org::Locations::Fields::Component.new(form_builder: builder, organization:, current_country_id: Country.united_states_id))
        end
      end
    end
  end

  let(:component) { rendered_component(organization, location) }

  def slot(name) = component.at_css("[data-slot='#{name}']")

  it "renders a saved location as clean, with its pieces hidden until the state they're for" do
    expect(component).to have_field("Location name", with: "Main shop")
    expect(component).to have_field("Phone number")
    expect(component).to have_field("Street")
    expect(component).to have_field("Publicly visible", type: "checkbox")
    expect(component).to have_field("Impound location", type: "checkbox")
    expect(component).to have_field("If Brakebills has multiple locations where impounded bikes go and wants to track them", type: "checkbox", visible: :all)
    expect(component.at_css("[data-new-record]")["data-new-record"]).to eq "false"
    expect(component).to have_button("Remove")
    expect(component.css("[data-slot='destroy']").length).to eq 1

    expect(component.at_css("[data-slot='unsaved-row']")["class"]).to include("tw:hidden")
    expect(slot("badge-dirty")["class"]).to include("tw:hidden")
    expect(slot("badge-impound")["class"]).to include("tw:hidden")
    expect(slot("default-row")["class"]).to include("tw:hidden")
    # publicly visible, with the org on the map
    expect(slot("badge-map")["class"].to_s).not_to include("tw:hidden")
  end

  context "new location" do
    let(:location) { organization.locations.build }

    it "is unsaved from the start, and takes the organization's name" do
      expect(component.at_css("[data-new-record]")["data-new-record"]).to eq "true"
      expect(slot("badge-dirty").text).to match("New")
      expect(slot("badge-dirty")["class"].to_s).not_to include("tw:hidden")
      expect(slot("unsaved-row")["class"].to_s).not_to include("tw:hidden")
      expect(component).to have_field("Location name", with: "Brakebills")
    end
  end

  context "default impound location" do
    let(:location) { FactoryBot.create(:location, :with_address_record, organization:, name: "Lot", impound_location: true, default_impound_location: true) }

    it "badges it, and says why it can't be removed" do
      expect(slot("badge-default-impound")["class"].to_s).not_to include("tw:hidden")
      expect(slot("badge-impound")["class"]).to include("tw:hidden")
      expect(slot("default-row")["class"].to_s).not_to include("tw:hidden")
      expect(component).to have_text("Required for impounded bikes")
      expect(component).to have_no_button("Remove")
      expect(component.css("[data-slot='destroy']")).to be_empty
    end
  end

  context "organization not on the map, without impound" do
    let(:show_on_map) { false }
    let(:enabled_feature_slugs) { [] }

    it "hides publicly visible until the map is checked, and has no impound options" do
      expect(slot("public-row")["class"]).to include("tw:hidden")
      expect(slot("badge-map")["class"]).to include("tw:hidden")
      expect(component).to have_no_field("Impound location", visible: :all)
    end
  end
end
