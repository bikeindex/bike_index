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

  describe "panel_columns" do
    it "lists the always-visible view column with the toggleable ones, in label order" do
      expect(instance.panel_columns).to include("view_cell")
      expect(instance.enabled_columns).not_to include("view_cell")
      expect(instance.panel_columns).to eq(instance.panel_columns.sort_by { |cell| instance.panel_labels[cell.to_sym] })
    end
  end

  describe "panel_labels" do
    it "prefixes the time columns, leaving the table headers short" do
      expect(instance.panel_labels[:created_at_cell]).to eq "Time - registered"
      expect(instance.panel_labels[:updated_at_cell]).to eq "Time - updated"
      expect(instance.panel_labels[:acknowledgment_cell]).to eq "Time - Registration sequence acknowledged"
      expect(instance.column_renames[:created_at_cell]).to eq "Registered"
      expect(instance.panel_labels[:color_cell]).to eq "Color"
    end
  end

  describe "initially_checked_columns" do
    it "returns default columns" do
      cols = instance.initially_checked_columns
      expect(cols).to include("photo_cell", "created_at_cell", "manufacturer_cell", "model_cell",
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

    it "names the organization in its own columns" do
      expect(instance.column_renames[:color_cell]).to eq "Color"
      expect(instance.column_renames[:notes_cell]).to eq "Registration Notes <em>by #{organization.short_name}</em>"
      expect(instance.column_renames[:reg_student_id_cell]).to eq "Student ID <em>for #{organization.short_name}</em>"
    end
  end

  describe "enabled_columns" do
    let(:enabled_feature_slugs) { %w[bike_search impound_bikes] }

    it "adds the feature's columns" do
      expect(instance.enabled_columns).to include("impound_id_cell", "impounded_cell", "url_cell")
    end

    context "without impound_bikes" do
      let(:enabled_feature_slugs) { %w[bike_search] }

      it "doesn't include the impound columns" do
        expect(instance.enabled_columns).to_not include("impound_id_cell")
      end
    end
  end

  describe "filter_groups" do
    let(:enabled_feature_slugs) { %w[bike_search bike_stickers reg_address impound_bikes] }
    let(:search_status) { "impounded" }

    it "returns a group per enabled filter, carrying the searched value" do
      groups = instance.filter_groups
      expect(groups.map { it[:name] })
        .to eq(%i[search_stickers search_address search_status search_unregisteredness])
      expect(groups.find { it[:name] == :search_status }[:selected]).to eq "impounded"
      expect(groups.find { it[:name] == :search_stickers }[:entries].map { it[:value] })
        .to eq ["", "with", "none"]
    end

    context "with no optional features" do
      let(:enabled_feature_slugs) { %w[bike_search] }
      let(:search_status) { "all" }

      it "returns only the ungated ones, without the impound statuses" do
        groups = instance.filter_groups
        expect(groups.map { it[:name] }).to eq %i[search_status search_unregisteredness]
        expect(groups.find { it[:name] == :search_status }[:selected]).to eq "all"
        expect(groups.find { it[:name] == :search_status }[:entries].map { it[:value] })
          .to eq %w[all with_owner stolen]
      end
    end
  end

  describe "export_disabled?" do
    let(:enabled_feature_slugs) { %w[bike_search csv_exports] }

    it "is true once the search reaches past the organization, which still renders the export" do
      expect(instance.export_disabled?).to be false

      search_all = described_class.new(**options.merge(search_all: true))
      expect(search_all.render_export?).to be true
      expect(search_all.export_disabled?).to be true
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
end
