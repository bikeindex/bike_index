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
      expect(attributes[:controller]).to eq "org--multi-search ui--collapse ui--column-settings"
      expect(attributes[:"ui--collapse-storage-key-value"]).to eq "orgRegistrationColumnsOpen"
      expect(attributes[:"ui--column-settings-storage-key-value"]).to eq "orgRegistrationColumns"
    end

    it "orders the columns by default" do
      expect(described_class.column_settings_data_attributes[:"ui--table-column-order-storage-key-value"])
        .to eq "orgRegistrationColumnsOrder"
    end
  end

  it "renders the collapsed column panel, leaving its toggle and the export to the caller" do
    expect(component).to have_css("[data-ui--collapse-target='content']", visible: :all)
    expect(component).to have_css("input[type='checkbox'][data-ui--column-settings-target='checkbox']", visible: :all)
    expect(component).not_to have_button(visible: :all, text: /settings/i)
    expect(component).not_to have_text("Export CSV")
    expect(component.at_css("[data-ui--collapse-target='content']")[:class]).to include("tw:hidden!")
  end

  it "keeps View checked, out of the controller's reach" do
    expect(component).to have_field("view_cell", checked: true, disabled: true, visible: :all)
    expect(component.at_css("input[name='view_cell']")["data-ui--column-settings-target"]).to be_nil
  end

  it "labels the registration time columns, with the status column's hint" do
    expect(component).to have_text("Time - registration updated")
    expect(component).to have_text("Time - Registration status")
    expect(component.at_css("label:has(#column_settings_occurred_at_cell) small").text)
      .to eq "When registration was stolen, impounded, found or listed for sale"
  end

  context "with export_headers" do
    let(:instance) { described_class.new(settings:, export_headers: %w[serial]) }

    it "renders the export form's column fields, open, on their own" do
      expect(component).not_to have_css("[data-ui--collapse-target]")
      expect(component).to have_css("[data-controller='ui--column-settings']:not([data-ui--column-settings-storage-key-value])")
      expect(component).to have_text("Included columns")
      expect(component).to have_field("export[headers][]", with: "serial", checked: true)
      expect(component).to have_field("export_headers_registered_at", with: "registered_at", checked: false)
      expect(component.at_css("input[value='registered_at']")["data-default"]).to eq "true"
      expect(component).not_to have_field("view_cell")
    end
  end
end
