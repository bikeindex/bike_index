# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::BikeSearch::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) do
    with_request_url("/o/#{organization.to_param}/bikes") do
      render_inline(instance) { "<tr><td>bike row</td></tr>".html_safe }
    end
  end
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:) }
  let(:enabled_feature_slugs) { %w[bike_search] }
  let(:pagy) { Pagy::Offset.new(count: 25, page: 1, limit: 10) }
  let(:search_stickers) { nil }
  let(:search_address) { nil }
  let(:search_status) { "all" }
  let(:skip_search_and_filters) { false }
  let(:options) do
    {
      organization:,
      pagy:,
      per_page: 10,
      params: {},
      interpreted_params: {},
      sortable_search_params: {},
      search_stickers:,
      search_address:,
      search_status:,
      skip_search_and_filters:,
      stolenness: "all",
      time_range: 1.year.ago..Time.current
    }
  end

  it "renders table with form, checkboxes, and content block" do
    expect(component).to have_css("table.table")
    expect(component).to have_css("tbody tr", count: 1)
    expect(component).to have_css(".settings-list", visible: :all)
    # Search form
    expect(component).to have_css("#Search_Form")
    expect(component).to have_css("hr")
    # checkboxes
    expect(component).to have_css(".settings-list.tw\\:hidden\\!", visible: :all)
    expect(component).to have_css("input[type='checkbox']", visible: :all)
    # pagination
    expect(component).to have_css(".paginate-container")
    expect(component).to have_css("select#per_page_select")
  end

  context "with skip_search_and_filters" do
    let(:skip_search_and_filters) { true }

    it "renders table without search form" do
      expect(component).to have_css("table.table")
      expect(component).not_to have_css("#Search_Form")
      expect(component).not_to have_css("hr")
    end
  end

  context "with bike_stickers enabled" do
    let(:enabled_feature_slugs) { %w[bike_search bike_stickers] }

    it "renders sticker filter buttons" do
      expect(component).to have_css(".search-sort-btns", text: /Stickers/, visible: :all)
    end
  end

  context "with impound_bikes enabled" do
    let(:enabled_feature_slugs) { %w[bike_search impound_bikes] }

    it "renders impound status filter buttons" do
      expect(component).to have_css(".search-sort-btns", text: /Status/, visible: :all)
      expect(component).to have_css(".search-sort-btns a", text: /not/, visible: :all)
    end
  end

  context "with search_stickers filter active" do
    let(:enabled_feature_slugs) { %w[bike_search bike_stickers] }
    let(:search_stickers) { "with" }

    it "displays active filter description" do
      expect(component).to have_text("with stickers")
    end
  end

  context "with search_address filter active" do
    let(:search_address) { "without_street" }

    it "displays active filter description" do
      expect(component).to have_text("no address")
    end
  end

  context "with search_status filter active" do
    let(:search_status) { "stolen" }

    it "displays active filter description" do
      expect(component).to have_text("only stolen")
    end
  end

  context "with csv_exports enabled" do
    let(:enabled_feature_slugs) { %w[bike_search csv_exports] }

    it "renders export link" do
      expect(component).to have_link(text: /Create export/, visible: :all)
    end
  end
end
