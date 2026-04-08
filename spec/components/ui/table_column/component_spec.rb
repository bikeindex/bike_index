# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::TableColumn::Component do
  let(:no_sort_args) { {render_sortable: false, current_sort: nil, current_direction: "desc", sortable_url: nil} }

  describe "#th_classes" do
    let(:col) { described_class.new(label: "Name") }

    it "includes base classes" do
      expect(col.th_classes(bordered: false)).to include("tw:px-1 tw:py-2")
    end

    it "includes border classes when bordered" do
      result = col.th_classes(bordered: true)
      expect(result).to include("border-b")
      expect(result).to include("border-l")
    end

    it "includes custom classes" do
      col = described_class.new(label: "Name", classes: "text-xs")
      expect(col.th_classes(bordered: false)).to include("text-xs")
    end

    it "includes header_classes on th but not td" do
      col = described_class.new(label: "Name", header_classes: "w-32")
      expect(col.th_classes(bordered: false)).to include("w-32")
      expect(col.td_classes(bordered: false)).not_to include("w-32")
    end
  end

  describe "#td_classes" do
    let(:col) { described_class.new(label: "Name") }

    it "includes bordered classes when bordered" do
      result = col.td_classes(bordered: true)
      expect(result).to include("tw:border-b")
      expect(result).to include("tw:border-l")
    end

    it "includes unbordered classes when not bordered" do
      expect(col.td_classes(bordered: false)).to include("tw:border-b tw:border-gray-100")
    end
  end

  describe "#render_header" do
    it "returns label when render_sortable is false" do
      col = described_class.new(label: "Email", sortable: "email")
      expect(col.render_header(**no_sort_args)).to eq("Email")
    end

    it "derives title from sortable when no label" do
      col = described_class.new(sortable: "created_at")
      expect(col.render_header(**no_sort_args)).to eq("Created")
    end

    it "strips _id suffix from sortable" do
      col = described_class.new(sortable: "bike_sticker_batch_id")
      expect(col.render_header(**no_sort_args)).to eq("Bike Sticker Batch")
    end

    it "returns nil when neither label nor sortable" do
      col = described_class.new
      expect(col.render_header(**no_sort_args)).to be_nil
    end
  end
end
