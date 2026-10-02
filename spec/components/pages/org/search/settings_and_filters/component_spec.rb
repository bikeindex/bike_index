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

  context "with registration_notes enabled" do
    let(:enabled_feature_slugs) { %w[bike_search registration_notes] }

    it "renders the notes toggle" do
      expect(component).to have_text("show notes search")
    end
  end
end
