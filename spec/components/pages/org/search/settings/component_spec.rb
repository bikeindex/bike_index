# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::Search::Settings::Component, type: :component do
  let(:instance) { described_class.new(settings:, **options) }
  let(:component) do
    with_request_url("/o/#{organization.to_param}/registrations") do
      render_inline(instance)
    end
  end
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:) }
  let(:enabled_feature_slugs) { %w[bike_search] }
  let(:settings) { ComponentStructs::OrgSearchSettings.new(organization:) }
  let(:options) { {} }

  describe ".column_toggle_data_attributes" do
    it "runs a caller's own controller alongside its two" do
      attributes = described_class.column_toggle_data_attributes(settings, controllers: "org--multi-search")
      expect(attributes[:controller]).to eq "org--multi-search org--search org--search-column-toggle"
    end
  end

  it "renders the column panel and its toggle button" do
    expect(component).to have_css("[data-ui--collapse-target='content']", visible: :all)
    expect(component).to have_css("input[type='checkbox']", visible: :all)
    expect(component).to have_button("settings", visible: :all)
  end

  context "with toggle_button false" do
    let(:options) { {toggle_button: false} }

    it "leaves the button to the caller" do
      expect(component).to have_css("[data-ui--collapse-target='content']", visible: :all)
      expect(component).not_to have_button("settings", visible: :all)
    end
  end

  context "with csv_exports enabled" do
    let(:enabled_feature_slugs) { %w[bike_search csv_exports] }

    it "renders the export disabled, since the panel's search isn't the page's bikes" do
      expect(component).to have_css("a[aria-disabled='true']:not([href])", text: "Export CSV", visible: :all)
      expect(component).to have_css("button[aria-label=\"Can't create export of this\"]", visible: :all)
    end

    context "with toggle_button false" do
      let(:options) { {toggle_button: false} }

      it "leaves the export to the caller too" do
        expect(component).not_to have_link("Export CSV", visible: :all)
      end
    end
  end
end
