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
      attributes = described_class.column_settings_data_attributes(settings, controllers: "org--multi-search")
      expect(attributes[:controller]).to eq "org--multi-search org--search org--search-column-settings"
      expect(attributes.keys).not_to include(:"ui--collapse-storage-key-value")
    end

    it "adds the collapse with collapse: true" do
      attributes = described_class.column_settings_data_attributes(settings, collapse: true)
      expect(attributes[:controller]).to eq "ui--collapse org--search org--search-column-settings"
      expect(attributes[:"ui--collapse-storage-key-value"]).to eq "orgRegistrationColumnsOpen"
    end
  end

  it "renders the column panel, leaving its toggle and the export to the caller" do
    expect(component).to have_css("[data-ui--collapse-target='content']", visible: :all)
    expect(component).to have_css("input[type='checkbox']", visible: :all)
    expect(component).not_to have_button(visible: :all, text: /settings/i)
    expect(component).not_to have_text("Export CSV")
    expect(component).to have_button("Close", visible: :all)
    expect(component.at_css("[data-ui--collapse-target='content']")[:class]).to include("tw:hidden!")
  end

  context "with open: true" do
    let(:instance) { described_class.new(settings:, open: true) }

    it "renders the panel expanded" do
      expect(component.at_css("[data-ui--collapse-target='content']")[:class]).not_to include("tw:hidden!")
    end
  end
end
