# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::PaginationWithCount::Component, type: :component do
  let(:collection) { Bike.limit(10) }

  describe "count display" do
    let(:component) { render_inline(described_class.new(**options)) }

    context "with explicit count and skip_pagination" do
      let(:options) { {collection:, count: 42, skip_pagination: true, params: {}} }

      it "renders the provided count" do
        expect(component.text).to include("42")
        expect(component.text).to include("Matching")
      end
    end

    context "with viewing override and skip_pagination" do
      let(:options) { {collection:, viewing: "Custom Items", skip_pagination: true, params: {}} }

      it "renders custom viewing text" do
        expect(component.text).to include("Custom Items")
        expect(component.text).to include("Matching")
      end
    end

    context "without viewing override and skip_pagination" do
      let(:options) { {collection:, skip_pagination: true, params: {}} }

      it "uses inferred viewing text" do
        expect(component.text).to include("Bikes")
        expect(component.text).to include("Matching")
      end
    end

    context "with skip_total true" do
      let(:options) { {collection:, skip_total: true, skip_pagination: true, params: {}} }

      it "does not render count section" do
        expect(component.text).not_to include("Matching")
      end
    end
  end

  describe "pagination controls" do
    context "with skip_pagination true" do
      let(:options) { {collection:, skip_pagination: true, params: {}} }
      let(:component) { render_inline(described_class.new(**options)) }

      it "does not render pagination controls" do
        expect(component.css("select")).to be_blank
      end

      it "renders count section" do
        expect(component.text).to include("Matching")
      end
    end

    context "with both skip_total and skip_pagination" do
      let(:options) { {collection:, skip_total: true, skip_pagination: true, params: {}} }
      let(:component) { render_inline(described_class.new(**options)) }

      it "renders minimal output" do
        expect(component.css(".row")).to be_present
        expect(component.text.strip).to be_blank
      end
    end
  end

  describe "component structure" do
    let(:options) { {collection:, skip_pagination: true, params: {}} }
    let(:component) { render_inline(described_class.new(**options)) }

    it "renders within a row div" do
      expect(component.css("div.row")).to be_present
    end

    it "renders count in col-md-5 when not skipped" do
      expect(component.css("div.col-md-5 p.pagination-number")).to be_present
    end

    it "displays count with strong tag" do
      expect(component.css("strong")).to be_present
    end
  end

  describe "viewing text pluralization" do
    let(:options) { {collection:, viewing: "Item", count: 1, skip_pagination: true, params: {}} }
    let(:component) { render_inline(described_class.new(**options)) }

    it "pluralizes viewing text based on count" do
      expect(component.text).to include("Matching Item")
    end

    context "with multiple items" do
      let(:options) { {collection:, viewing: "Item", count: 5, skip_pagination: true, params: {}} }

      it "uses plural form" do
        expect(component.text).to include("Matching Items")
      end
    end
  end
end
