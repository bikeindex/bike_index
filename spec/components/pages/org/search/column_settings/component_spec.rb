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
    it "runs a caller's own controllers alongside the shared column settings, off the org's storage key" do
      attributes = described_class.column_settings_data_attributes(controllers: "org--multi-search", orderable: false)
      expect(attributes[:controller]).to eq "org--multi-search ui--collapse ui--table-column-settings"
      expect(attributes[:"ui--collapse-storage-key-value"]).to eq "orgRegistrationColumnsOpen"
      expect(attributes[:"ui--table-column-settings-storage-key-value"]).to eq "orgRegistrationColumns"
    end

    it "orders the columns by default" do
      expect(described_class.column_settings_data_attributes[:"ui--table-column-order-storage-key-value"])
        .to eq "orgRegistrationColumnsOrder"
    end

    it "keeps the impound records search's choices apart" do
      expect(described_class.column_settings_data_attributes(impound: true)[:"ui--table-column-settings-storage-key-value"])
        .to eq "orgImpoundColumns"
    end
  end

  it "renders the collapsed column panel, leaving its toggle and the export to the caller" do
    expect(component).to have_css("[data-ui--collapse-target='content']", visible: :all)
    expect(component).to have_css("input[type='checkbox'][data-ui--table-column-settings-target='checkbox']", visible: :all)
    expect(component).not_to have_button(visible: :all, text: /settings/i)
    expect(component).not_to have_text("Export CSV")
    expect(component.at_css("[data-ui--collapse-target='content']")[:class]).to include("tw:hidden!")
  end

  it "lists every column together, with nothing to copy an order from" do
    expect(component).to have_no_css("h3", text: "Impound search columns", visible: :all)
    expect(component).to have_no_css("[data-ui--table-column-order-target='copy']", visible: :all)
  end

  context "with the impound records search" do
    let(:enabled_feature_slugs) { %w[bike_search impound_bikes] }

    it "copies the impound records search's column order" do
      expect(component).to have_css("button[data-ui--table-column-order-target='copy'][data-storage-key='orgImpoundColumnsOrder']",
        text: "Copy column order from impounded vehicles search", visible: :all)
      expect(component).to have_no_css("h3", text: "Impound search columns", visible: :all)
    end

    context "unordered, as the multi-serial search is" do
      let(:instance) { described_class.new(settings:, orderable: false) }

      it "leaves out the order buttons" do
        expect(component).to have_no_css("[data-ui--table-column-order-target]", visible: :all)
      end
    end
  end

  it "keeps View checked, out of the controller's reach" do
    expect(component).to have_field("view_cell", checked: true, disabled: true, visible: :all)
    expect(component.at_css("input[name='view_cell']")["data-ui--table-column-settings-target"]).to be_nil
  end

  it "labels the registration time columns, with the status column's hint" do
    expect(component).to have_text("Time - Registration Updated")
    expect(component).to have_text("Time - Status")
    expect(component.at_css("label:has(#table_column_settings_occurred_at_cell) small").text)
      .to eq "when stolen, impounded, etc"
  end

  context "with impound settings" do
    let(:enabled_feature_slugs) { %w[bike_search impound_bikes] }
    let(:settings) { ComponentStructs::OrgSearchSettings.new(organization:, impound: true) }

    it "lists the impound columns under their own heading, on by default, and copies the registrations search's order" do
      checkboxes = ComponentStructs::OrgSearchSettings::IMPOUND_COLUMNS.map { component.at_css("input[name='#{it}']") }
      expect(checkboxes.map { it["data-default"] }.uniq).to eq ["true"]
      expect(component).to have_text("Time - Impounded", normalize_ws: true)
      expect(component).to have_text("Time - Resolved")
      expect(component).to have_text("Impound status")
      expect(component.at_css("input[name='impound_id_cell']")["data-default"]).to eq "true"
      after_heading = component.css("h3, input[type='checkbox']").map { it[:name] || it.text.strip }.drop_while { it != "Impound search columns" }.drop(1)
      expect(after_heading).to match_array(settings.impound_panel_columns)
      expect(component).to have_css("button[data-ui--table-column-order-target='copy'][data-storage-key='orgRegistrationColumnsOrder']",
        text: "Copy column order from registrations search", visible: :all)
    end
  end

  context "with export_headers" do
    let(:instance) { described_class.new(settings:, export_headers: %w[serial]) }

    it "renders the export form's column fields, open, on their own" do
      expect(component).not_to have_css("[data-ui--collapse-target]")
      expect(component).to have_css("[data-controller='ui--table-column-settings']:not([data-ui--table-column-settings-storage-key-value])")
      expect(component).to have_text("Included columns")
      expect(component).to have_field("export[headers][]", with: "serial", checked: true)
      expect(component).to have_field("export_headers_registered_at", with: "registered_at", checked: false)
      expect(component.at_css("input[value='registered_at']")["data-default"]).to eq "true"
      expect(component).not_to have_field("view_cell")
    end
  end
end
