# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::PaginationWithCount::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  # No pagy, so the pagination half doesn't render unless a context supplies one
  let(:options) { {collection:, index: ComponentStructs::IndexState.new} }
  let(:collection) { Bike.limit(10) }

  describe "time range" do
    let(:options) do
      {collection:, viewing: "Bikes",
       index: ComponentStructs::IndexState.new(period: "week", time_range: (Time.current - 1.week)..Time.current)}
    end

    it "renders the humanized range" do
      expect(component.text).to include("in the past week")
    end

    context "with period all" do
      let(:options) { super().merge(index: ComponentStructs::IndexState.new(period: "all", time_range: (Time.current - 1.week)..Time.current)) }

      it "renders no range" do
        expect(component.text).to_not include("in the past")
      end
    end
  end

  describe "count display" do
    context "with explicit count" do
      let(:options) { super().merge(count: 42) }

      it "renders the provided count" do
        expect(component.text).to include("42")
        expect(component.text).to include("Matching")
      end
    end

    context "with viewing override" do
      let(:options) { super().merge(viewing: "Custom Items") }

      it "renders custom viewing text" do
        expect(component.text).to include("Custom Items")
        expect(component.text).to include("Matching")
      end
    end

    context "without viewing override" do
      it "uses inferred viewing text" do
        expect(component.text).to include("Bikes")
        expect(component.text).to include("Matching")
      end
    end

    context "with skip_total true" do
      let(:options) { super().merge(skip_total: true) }

      it "does not render count section" do
        expect(component.text).not_to include("Matching")
      end
    end
  end

  describe "pagination controls" do
    it "renders none without a pagy" do
      expect(component.css("select")).to be_blank
      expect(component.text).to include("Matching")
    end

    context "with a pagy" do
      # The page links resolve against the current route, so this one needs a request
      let(:component) { with_request_url("/admin/bikes") { render_inline(instance) } }
      let(:options) { super().merge(index: ComponentStructs::IndexState.new(pagy: Pagy::Offset.new(count: 100, limit: 25, page: 1), per_page: 25)) }

      it "renders the per-page select and the page links" do
        expect(component.css("select#per_page_select")).to be_present
        expect(component.css("a[href='/admin/bikes?page=2']")).to be_present
      end
    end

    context "with skip_total and no pagy" do
      let(:options) { super().merge(skip_total: true) }

      it "renders minimal output" do
        expect(component.css(".row")).to be_present
        expect(component.text.strip).to be_blank
      end
    end
  end

  describe "component structure" do
    it "renders within a row div" do
      expect(component.css("div.row")).to be_present
      expect(component.css("div.col-md-5 p.pagination-number")).to be_present
      expect(component.css("strong")).to be_present
    end
  end

  describe "viewing text pluralization" do
    let(:options) { super().merge(viewing: "Item", count:) }
    let(:count) { 1 }

    it "pluralizes viewing text based on count" do
      expect(component.text).to match(/Matching\s+Item/)
      expect(component.text).to_not match(/Matching\s+Items/)
    end

    context "with multiple items" do
      let(:count) { 5 }

      it "uses plural form" do
        expect(component.text).to match(/Matching\s+Items/)
      end
    end
  end
end
