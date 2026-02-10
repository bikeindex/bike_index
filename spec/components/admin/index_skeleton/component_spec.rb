# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::IndexSkeleton::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  # Always provide table_view to avoid needing a _table partial in tests
  let(:options) { {table_view: "<div>table</div>".html_safe} }

  def render_component
    with_request_url("/admin") do
      ctrl = vc_test_controller
      ctrl.instance_variable_set(:@render_chart, false)
      ctrl.instance_variable_set(:@collection, Bike.none)
      ctrl.instance_variable_set(:@pagy, nil)
      ctrl.instance_variable_set(:@per_page, 25)
      ctrl.instance_variable_set(:@time_range, nil)
      ctrl.instance_variable_set(:@period, "all")
      ctrl.instance_variable_set(:@start_time, Time.current - 1.year)
      ctrl.instance_variable_set(:@end_time, Time.current)
      render_inline(instance)
    end
  end

  let(:component) { render_component }

  describe "title" do
    it "renders default Manage title from controller name" do
      expect(component.text).to include("Manage")
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

  describe "admin-subnav layout" do
    it "uses tailwind flex-row layout" do
      expect(component).to have_css("div.tw\\:flex.tw\\:flex-row.tw\\:items-baseline")
    end

    it "renders h1 and ul" do
      expect(component).to have_css("h1")
      expect(component).to have_css("ul")
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

  describe "nav_header_list_items" do
    let(:options) { super().merge(nav_header_list_items: '<li class="nav-item"><a class="nav-link" href="#">Custom</a></li>'.html_safe) }

    it "renders custom nav items" do
      expect(component).to have_css("li.nav-item a", text: "Custom")
    end
  end

  describe "admin_search_form" do
    let(:options) { super().merge(admin_search_form: '<form class="test-search-form"><input /></form>'.html_safe) }

    it "renders the search form" do
      expect(component).to have_css("form.test-search-form")
    end
  end

  describe "table_view" do
    let(:options) { {table_view: '<div class="custom-table">Table content</div>'.html_safe} }

    it "renders the provided table view" do
      expect(component).to have_css("div.custom-table", text: "Table content")
    end
  end
end
