# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::Search::Filters::Component, type: :component do
  let(:component) do
    with_request_url("/o/#{organization.to_param}/registrations") do
      render_inline(described_class.new(**options))
    end
  end
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:) }
  let(:enabled_feature_slugs) { %w[bike_search bike_stickers] }
  let(:settings_component) do
    Pages::Org::Search::Settings::Component.new(organization:, search_stickers:, search_status: "all")
  end
  let(:search_stickers) { nil }
  let(:options) do
    {settings_component:, period: "week", start_time: Time.current - 1.week, end_time: Time.current}
  end

  it "renders the chip row and the collapsed settings panel" do
    expect(component).to have_text("Quick filters")
    expect(component).to have_button("E-bike only")
    expect(component).to have_button("Without sticker")
    expect(component).to have_text("past 7 days")
    expect(component).to have_css("[data-org--search-target='filters'].tw\\:hidden\\!", visible: :all)
  end

  it "renders each filter group's radios against the search form" do
    expect(component).to have_css("input[type='radio'][name='search_stickers'][form='Search_Form']", visible: :all)
    expect(component).to have_css("input[type='radio'][name='search_status'][form='Search_Form']", visible: :all)
  end

  context "with the sticker filter on" do
    let(:search_stickers) { "none" }

    it "marks the chip active" do
      expect(component).to have_css("button[data-quick-filter-value='none'][data-active]")
    end
  end

  context "without registration_notes" do
    it "leaves out the notes toggle" do
      expect(component).not_to have_text("show notes search")
    end
  end

  context "with notes_search" do
    let(:options) { super().merge(notes_search: true) }

    it "renders the notes toggle" do
      expect(component).to have_text("show notes search")
    end
  end
end
