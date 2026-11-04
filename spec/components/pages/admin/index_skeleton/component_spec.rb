# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::IndexSkeleton::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  # Always provide table_view to avoid needing a _table partial in tests
  let(:options) do
    {table_view: "<div>table</div>".html_safe, collection: Bike.none, viewing: "Bikes",
     index: ComponentStructs::IndexState.new(per_page: 25, period: "all", start_time: Time.current - 1.year,
       end_time: Time.current)}
  end

  let(:component) { with_request_url("/admin") { render_inline(instance) } }

  describe "title" do
    it "renders Manage with the passed viewing" do
      expect(component.text).to include("Manage")
      expect(component.text).to include("Bikes")
    end

    context "with custom viewing" do
      let(:options) { super().merge(viewing: "Organization Statuses") }

      it "renders viewing in title" do
        expect(component.text).to include("Manage")
        expect(component.text).to include("Organization Statuses")
      end
    end

    context "with custom index_title" do
      let(:options) { super().merge(index_title: "Custom Title") }

      it "renders the custom title" do
        expect(component.text).to include("Custom Title")
        expect(component.text).not_to include("Manage")
      end
    end
  end

  describe "graph toggle" do
    it "renders graph link by default" do
      expect(component).to have_css("a", text: "graph")
    end

    context "with skip_charting" do
      let(:options) { super().merge(skip_charting: true) }

      it "does not render graph link" do
        expect(component).not_to have_css("a", text: "graph")
      end
    end
  end

  describe "nav items" do
    let(:component) do
      with_request_url("/admin") do
        render_inline(instance) { |skeleton| skeleton.with_nav_item { '<a href="#">Custom</a>'.html_safe } }
      end
    end

    it "lists them before its own" do
      expect(component.css("ul li a").map { |link| link.text.strip }.first(2)).to eq ["Custom", "graph"]
    end
  end

  describe "admin_search_form" do
    let(:options) { super().merge(admin_search_form: '<form class="test-search-form"><input /></form>'.html_safe) }

    it "renders the search form" do
      expect(component).to have_css("form.test-search-form")
    end
  end

  describe "table_view" do
    let(:options) { super().merge(table_view: '<div class="custom-table">Table content</div>'.html_safe) }

    it "renders the provided table view" do
      expect(component).to have_css("div.custom-table", text: "Table content")
    end
  end
end
