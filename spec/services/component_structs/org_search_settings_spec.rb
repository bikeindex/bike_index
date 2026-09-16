# frozen_string_literal: true

require "rails_helper"

RSpec.describe ComponentStructs::OrgSearchSettings do
  let(:instance) { described_class.new(**options) }
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:) }
  let(:enabled_feature_slugs) { %w[bike_search] }
  let(:search_stickers) { nil }
  let(:search_address) { nil }
  let(:search_status) { "all" }
  let(:options) { {organization:, search_stickers:, search_address:, search_status:} }

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

  describe "column_renames" do
    let(:enabled_feature_slugs) { %w[bike_search reg_student_id] }

    it "prefixes the organization's own columns with its short name" do
      expect(instance.column_renames[:color_cell]).to eq "Color"
      expect(instance.column_renames[:reg_student_id_cell]).to eq "#{organization.short_name} Student ID"
    end
  end

  describe "enabled_columns" do
    let(:enabled_feature_slugs) { %w[bike_search impound_bikes] }

    it "adds the feature's columns, sorted by label" do
      expect(instance.enabled_columns).to include("impound_id_cell", "impounded_cell", "url_cell")
      expect(instance.enabled_columns).to eq(instance.enabled_columns.sort_by { |cell| instance.column_renames[cell.to_sym] })
    end

    context "without impound_bikes" do
      let(:enabled_feature_slugs) { %w[bike_search] }

      it "doesn't include the impound columns" do
        expect(instance.enabled_columns).to_not include("impound_id_cell")
      end
    end
  end

  describe "column_toggle_data_attributes" do
    it "carries the default columns for the Stimulus controller" do
      expect(instance.column_toggle_data_attributes[:controller]).to eq "org--search org--search-column-toggle"
      expect(JSON.parse(instance.column_toggle_data_attributes[:"org--search-column-toggle-default-columns-value"]))
        .to eq instance.initially_checked_columns
    end
  end

  describe "default_open?" do
    it "is false" do
      expect(instance.default_open?).to be_falsey
    end

    context "with search_address" do
      let(:search_address) { "with_street" }

      it "is true" do
        expect(instance.default_open?).to be_truthy
      end
    end

    context "with search_open param" do
      let(:options) { super().merge(params: {search_open: "true"}) }

      it "is true" do
        expect(instance.default_open?).to be_truthy
      end
    end
  end

  describe "search_params" do
    let(:options) do
      super().merge(sortable_search_params: {sort: "id"}, interpreted_params: {query_items: ["v_1"]})
    end

    it "merges the interpreted params over the sortable ones, with the organization" do
      expect(instance.search_params)
        .to eq({sort: "id", query_items: ["v_1"], organization_id: organization.to_param})
    end
  end

  describe "cycle_type" do
    it "is the registration label" do
      expect(instance.cycle_type).to eq "registration"
    end
  end
end
