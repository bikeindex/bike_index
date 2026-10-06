# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::Search::ColumnSettings::Component, type: :component do
  let(:instance) { described_class.new(settings:) }
  let(:component) do
    with_request_url("/o/#{organization.to_param}/registrations") do
      render_inline(instance)
    end
  end
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:) }
  let(:enabled_feature_slugs) { %w[bike_search csv_exports] }
  let(:settings) { ComponentStructs::OrgSearchSettings.new(organization:) }

  describe ".column_settings_data_attributes" do
    it "runs a caller's own controller alongside its two" do
      attributes = described_class.column_settings_data_attributes(controllers: "org--multi-search")
      expect(attributes[:controller]).to eq "org--multi-search org--search org--search-column-settings"
      expect(attributes.keys).not_to include(:"ui--collapse-storage-key-value")
    end

    it "adds the collapse with collapse: true" do
      attributes = described_class.column_settings_data_attributes(collapse: true)
      expect(attributes[:controller]).to eq "ui--collapse org--search org--search-column-settings"
      expect(attributes[:"ui--collapse-storage-key-value"]).to eq "orgRegistrationColumnsOpen"
    end
  end

  it "renders the column panel, leaving its toggle and the export to the caller" do
    expect(component).to have_css("[data-ui--collapse-target='content']", visible: :all)
    expect(component).to have_css("input[type='checkbox']", visible: :all)
    expect(component).not_to have_button(visible: :all, text: /settings/i)
    expect(component).not_to have_text("Export CSV")
    expect(component).to have_field("view_cell", checked: true, disabled: true, visible: :all)
    expect(component.at_css("[data-ui--collapse-target='content']")[:class]).to include("tw:hidden!")
  end

  it "labels the registration time columns, with the status column's hint, and no impound columns" do
    expect(component).to have_field("updated_at_cell", visible: :all)
    expect(component).to have_text("Time - registration updated")
    expect(component).to have_text("Time - Registration status")
    expect(component.at_css("label:has(#occurred_at_cell_occurred_at_cell) small").text)
      .to eq "When registration was stolen, impounded, found or listed for sale"
    expect(component).not_to have_text("Impound columns")
  end

  context "with impound settings" do
    let(:enabled_feature_slugs) { %w[bike_search impound_bikes] }
    let(:settings) { ComponentStructs::OrgSearchSettings.new(organization:, impound: true) }

    it "renders the impound columns as a group of their own, all on by default" do
      expect(component).to have_text("Impound columns")
      expect(component).to have_css("[data-controller='org--column-checkboxes']", count: 2, visible: :all)
      impound_group = component.css("[data-controller='org--column-checkboxes']").last
      expect(impound_group.css("input[type='checkbox']").map { it[:name] })
        .to eq ComponentStructs::OrgSearchSettings::IMPOUND_COLUMNS
      expect(impound_group.css("input[type='checkbox']").map { it["data-default"] }.uniq).to eq ["true"]
      expect(impound_group.text).to include("Time - Impounded", "Time - impound record Updated", "Time - Resolved",
        "Impound status", "Last updator", "Impounded from", "Unregistered")
      expect(component.at_css("input[name='impound_id_cell']")["data-default"]).to eq "true"
    end
  end

  context "with export_headers" do
    let(:instance) { described_class.new(settings:, export_headers: %w[serial]) }

    it "renders the export form's column fields, open, without the View button" do
      expect(component).not_to have_css("[data-ui--collapse-target]")
      expect(component).to have_text("Included columns")
      expect(component).to have_field("export[headers][]", with: "serial", checked: true)
      expect(component).to have_field("export[headers][]", with: "registered_at", checked: false)
      expect(component.at_css("input[value='registered_at']")["data-default"]).to eq "true"
      expect(component).not_to have_field("view_cell")
    end
  end

  context "with open: true" do
    let(:instance) { described_class.new(settings:, open: true) }

    it "renders the panel expanded" do
      expect(component.at_css("[data-ui--collapse-target='content']")[:class]).not_to include("tw:hidden!")
    end
  end
end
