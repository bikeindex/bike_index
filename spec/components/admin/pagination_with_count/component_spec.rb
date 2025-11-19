# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::PaginationWithCount::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:options) { {collection:} }
  let(:collection) { Bike.all }

  describe "#count" do
    context "with explicit count" do
      let(:options) { {collection:, count: 42} }

      it "returns the provided count" do
        expect(instance.count).to eq(42)
      end
    end

    context "with pagy that responds to count" do
      let(:pagy) { double("Pagy", count: 100) }
      let(:options) { {collection:, pagy:} }

      it "returns pagy count" do
        expect(instance.count).to eq(100)
      end
    end
  end

  describe "#viewing" do
    context "with explicit viewing" do
      let(:options) { {collection:, viewing: "Custom Items"} }

      it "returns the provided viewing text" do
        expect(instance.viewing).to eq("Custom Items")
      end
    end

    context "without explicit viewing" do
      it "infers from collection table name" do
        expect(instance.viewing).to eq("Bikes")
      end
    end
  end

  describe "#show_time_range?" do
    context "with time_range and period not all" do
      let(:time_range) { (1.week.ago..Time.current) }
      let(:options) { {collection:, time_range:, period: "week"} }

      it "returns true" do
        expect(instance.show_time_range?).to be true
      end
    end

    context "with time_range but period is all" do
      let(:time_range) { (1.week.ago..Time.current) }
      let(:options) { {collection:, time_range:, period: "all"} }

      it "returns false" do
        expect(instance.show_time_range?).to be false
      end
    end

    context "without time_range" do
      let(:options) { {collection:, period: "week"} }

      it "returns false" do
        expect(instance.show_time_range?).to be false
      end
    end
  end

  describe "#per_pages" do
    context "with per_page" do
      let(:options) { {collection:, per_page: 75} }

      it "returns unique sorted array including per_page" do
        expect(instance.per_pages).to eq([10, 25, 50, 75, 100])
      end
    end

    context "without per_page" do
      let(:options) { {collection:} }

      it "returns default array" do
        expect(instance.per_pages).to eq([0, 10, 25, 50, 100])
      end
    end
  end

  describe "#per_page_select_id" do
    context "with skip_total false" do
      let(:options) { {collection:, skip_total: false} }

      it "returns base id" do
        expect(instance.per_page_select_id).to eq("per_page_select")
      end
    end

    context "with skip_total true" do
      let(:options) { {collection:, skip_total: true} }

      it "returns id with suffix" do
        expect(instance.per_page_select_id).to eq("per_page_select-skiptotal")
      end
    end
  end
end
