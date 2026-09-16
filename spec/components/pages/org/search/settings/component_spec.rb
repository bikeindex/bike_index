# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::Search::Settings::Component, type: :component do
  let(:instance) { described_class.new(settings: ComponentStructs::OrgSearchSettings.new(**settings_options), skip_search_and_filters:) }
  let(:component) do
    with_request_url("/o/#{organization.to_param}/registrations") do
      render_inline(instance)
    end
  end
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:) }
  let(:enabled_feature_slugs) { %w[bike_search] }
  let(:search_stickers) { nil }
  let(:settings_options) { {organization:, search_stickers:} }
  let(:skip_search_and_filters) { false }

  describe ".column_toggle_data_attributes" do
    let(:settings) { ComponentStructs::OrgSearchSettings.new(**settings_options) }

    it "runs a caller's own controller alongside its two" do
      attributes = described_class.column_toggle_data_attributes(settings, controllers: "org--multi-search")
      expect(attributes[:controller]).to eq "org--multi-search org--search org--search-column-toggle"
    end
  end

  it "renders settings panel with columns and settings button" do
    expect(component).to have_css("[data-org--search-target='settings']", visible: :all)
    expect(component).to have_css("input[type='checkbox']", visible: :all)
    expect(component).to have_button("settings", visible: :all)
  end

  context "with bike_stickers enabled" do
    let(:enabled_feature_slugs) { %w[bike_search bike_stickers] }

    it "renders sticker filter radios" do
      expect(component).to have_text("Stickers")
      expect(component).to have_css("input[type='radio'][name='search_stickers']", visible: :all)
    end
  end

  context "with impound_bikes enabled" do
    let(:enabled_feature_slugs) { %w[bike_search impound_bikes] }

    it "renders impound status filter radios" do
      expect(component).to have_text("Status")
      expect(component).to have_css("input[type='radio'][name='search_status'][value='not_impounded']", visible: :all)
    end
  end

  context "with csv_exports enabled" do
    let(:enabled_feature_slugs) { %w[bike_search csv_exports] }

    it "renders export link" do
      expect(component).to have_link(text: /Create export/, visible: :all)
    end
  end

  context "with search_stickers active" do
    let(:enabled_feature_slugs) { %w[bike_search bike_stickers] }
    let(:search_stickers) { "with" }

    it "opens settings by default" do
      expect(component).to have_css("[data-org--search-target='settings']:not(.tw\\:hidden\\!)", visible: :all)
    end
  end

  context "with skip_search_and_filters" do
    let(:enabled_feature_slugs) { %w[bike_search bike_stickers] }
    let(:skip_search_and_filters) { true }

    it "renders the columns without the filters" do
      expect(component).to have_css("input[type='checkbox']", visible: :all)
      expect(component).to have_no_css("input[type='radio'][name='search_stickers']", visible: :all)
    end
  end
end
