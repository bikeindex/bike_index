# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::Search::SettingsAndFilters::Component, type: :component do
  let(:component) do
    with_request_url("/o/#{organization.to_param}/registrations") do
      render_inline(described_class.new(**options))
    end
  end
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:) }
  let(:enabled_feature_slugs) { %w[bike_search bike_stickers] }
  let(:settings) do
    ComponentStructs::OrgSearchSettings.new(organization:, search_stickers:, search_status: "all")
  end
  let(:search_stickers) { nil }
  let(:options) do
    {settings:, period: "week", start_time: Time.current - 1.week, end_time: Time.current}
  end

  it "renders the settings trigger, the period, the collapsed panel and its radios" do
    expect(component).to have_button("Search settings and filters")
    expect(component).to have_text("past 7 days")
    expect(component).to have_css("[data-ui--collapse-target='content'].tw\\:hidden\\!", visible: :all)
    expect(component).to have_css("input[type='radio'][name='search_stickers'][form='Search_Form']", visible: :all)
    expect(component).to have_css("input[type='radio'][name='search_status'][form='Search_Form']", visible: :all)
    # The notes toggle is registration_notes' own
    expect(component).not_to have_text("show notes search")
  end

  context "with the sticker filter on" do
    let(:search_stickers) { "none" }

    it "says what the search is filtered to" do
      expect(component).to have_text("only no sticker")
    end
  end

  context "with impound settings" do
    let(:settings) do
      ComponentStructs::OrgImpoundSearchSettings.new(statuses: %w[current resolved all retrieved_by_owner],
        search_status: "current", search_unregisteredness: "only_unregistered")
    end

    it "renders the status and registration radios, with no notes or location toggles" do
      expect(component).to have_css("input[type='radio'][name='search_status'][value='retrieved_by_owner']", visible: :all)
      expect(component).to have_css("input[type='radio'][name='search_unregisteredness'][value='all']", visible: :all)
      expect(component).to have_css("input[type='radio'][name='period'][form='Search_Form']", visible: :all)
      expect(component).to have_text("Current records · Only unregistered")
      expect(component).not_to have_css("#show_location_search", visible: :all)
      expect(component).not_to have_text("show notes search")
    end
  end

  context "with an impound search to point to" do
    let(:enabled_feature_slugs) { %w[bike_search impound_bikes] }
    let(:impound_search_path) { "/o/#{organization.to_param}/impound_records" }
    let(:options) { super().merge(impound_search_path:) }
    let(:settings) { ComponentStructs::OrgSearchSettings.new(organization:, search_status:) }
    let(:search_status) { "impounded" }

    it "points only impounded at the impounded vehicles search" do
      line = component.at_css("[data-org--search-target='impoundSearchLink']")
      expect(line.text.squish).to eq "View in the impounded vehicles search"
      expect(line.at_css("a")[:href]).to eq impound_search_path
      expect(line[:hidden]).to be_nil
    end

    context "with another status" do
      let(:search_status) { "stolen" }

      it "renders the line hidden, for org--search to show" do
        expect(component.at_css("[data-org--search-target='impoundSearchLink']")[:hidden]).to be_present
      end
    end
  end

  context "with registration_notes enabled" do
    let(:enabled_feature_slugs) { %w[bike_search registration_notes] }

    it "renders the notes toggle" do
      expect(component).to have_text("show notes search")
    end
  end
end
