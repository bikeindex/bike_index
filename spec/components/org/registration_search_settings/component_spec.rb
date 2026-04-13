# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::RegistrationSearchSettings::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) do
    with_request_url("/o/#{organization.to_param}/registrations") do
      render_inline(instance)
    end
  end
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:) }
  let(:enabled_feature_slugs) { %w[bike_search] }
  let(:search_stickers) { nil }
  let(:search_address) { nil }
  let(:search_status) { "all" }
  let(:options) do
    {
      organization:,
      params: {},
      interpreted_params: {},
      sortable_search_params: {},
      search_stickers:,
      search_address:,
      search_status:
    }
  end

  describe "active_search_filter_descriptions" do
    it "returns empty when no filters active" do
      expect(instance.active_search_filter_descriptions).to eq([])
    end

    context "with search_stickers: with" do
      let(:search_stickers) { "with" }

      it "returns sticker filter description" do
        descriptions = instance.active_search_filter_descriptions
        expect(descriptions.length).to eq(1)
        expect(descriptions.first).to include("stickers")
      end
    end

    context "with search_stickers: none" do
      let(:search_stickers) { "none" }

      it "returns no sticker filter description" do
        descriptions = instance.active_search_filter_descriptions
        expect(descriptions.length).to eq(1)
        expect(descriptions.first).to include("no")
        expect(descriptions.first).to include("sticker")
      end
    end

    context "with search_address: with_street" do
      let(:search_address) { "with_street" }

      it "returns address filter description" do
        descriptions = instance.active_search_filter_descriptions
        expect(descriptions.length).to eq(1)
        expect(descriptions.first).to include("address")
      end
    end

    context "with search_address: without_street" do
      let(:search_address) { "without_street" }

      it "returns no address filter description" do
        descriptions = instance.active_search_filter_descriptions
        expect(descriptions.length).to eq(1)
        expect(descriptions.first).to include("no")
        expect(descriptions.first).to include("address")
      end
    end

    context "with search_status: stolen" do
      let(:search_status) { "stolen" }

      it "returns stolen filter description" do
        descriptions = instance.active_search_filter_descriptions
        expect(descriptions.length).to eq(1)
        expect(descriptions.first).to include("stolen")
      end
    end

    context "with search_status: impounded" do
      let(:search_status) { "impounded" }

      it "returns impounded filter description" do
        descriptions = instance.active_search_filter_descriptions
        expect(descriptions.length).to eq(1)
        expect(descriptions.first).to include("impounded")
      end
    end

    context "with search_status: not_impounded" do
      let(:search_status) { "not_impounded" }

      it "returns not impounded filter description" do
        descriptions = instance.active_search_filter_descriptions
        expect(descriptions.length).to eq(1)
        expect(descriptions.first).to include("not")
        expect(descriptions.first).to include("impounded")
      end
    end

    context "with search_status: with_owner" do
      let(:search_status) { "with_owner" }

      it "returns not stolen or impounded filter description" do
        descriptions = instance.active_search_filter_descriptions
        expect(descriptions.length).to eq(1)
        expect(descriptions.first).to include("not stolen or impounded")
      end
    end

    context "with multiple filters active" do
      let(:search_stickers) { "with" }
      let(:search_address) { "with_street" }
      let(:search_status) { "stolen" }

      it "returns all active filter descriptions" do
        expect(instance.active_search_filter_descriptions.length).to eq(3)
      end
    end
  end

  describe "initially_checked_columns" do
    it "returns default columns" do
      cols = instance.initially_checked_columns
      expect(cols).to include("created_at_cell", "manufacturer_cell", "model_cell",
        "color_cell", "owner_email_cell", "owner_name_cell", "creation_description_cell")
      expect(cols).not_to include("sticker_cell")
    end

    context "with bike_stickers enabled" do
      let(:enabled_feature_slugs) { %w[bike_search bike_stickers] }

      it "includes sticker_cell" do
        expect(instance.initially_checked_columns).to include("sticker_cell")
      end
    end

    context "with search_impoundedness impounded" do
      let(:options) { super().merge(params: {search_impoundedness: "impounded"}) }

      it "includes impounded_cell" do
        expect(instance.initially_checked_columns).to include("impounded_cell")
      end
    end
  end

  describe "rendering" do
    it "renders settings panel with columns and settings button" do
      expect(component).to have_css("[data-org--registration-search-target='settings']", visible: :all)
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
        expect(component).to have_css("[data-org--registration-search-target='settings']:not(.tw\\:hidden\\!)", visible: :all)
      end
    end
  end
end
