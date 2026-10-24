# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Search::MarketplaceIntro::Component, type: :component do
  include Rails.application.routes.url_helpers

  let(:dismissed) { false }
  let(:component) { render_inline(described_class.new(dismissed:, searched: false)) }
  let(:expanded) { "[data-search--marketplace-intro-target='expanded']" }
  let(:collapsed) { "[data-search--marketplace-intro-target='collapsed']" }

  it "shows the intro, with the dismissed row hidden" do
    expect(component).to have_css("#{expanded}:not(.tw\\:hidden)")
    expect(component).to have_css("#{collapsed}.tw\\:hidden")
    expect(component).to have_css("h1", text: "The used bike marketplace from the bike registry.")
    expect(component.text).to include("Checked for theft", "Bike Index members")
    expect(component).to have_link("How buying works", href: marketplace_how_it_works_path(anchor: "buying"))
    expect(component).to have_link("How selling works", href: marketplace_how_it_works_path(anchor: "selling"))
    # After the content, so it's tabbed to last
    expect(component).to have_css("img + button[aria-label='Hide intro'][data-action='search--marketplace-intro#hide']")
  end

  context "when dismissed" do
    let(:dismissed) { true }

    it "shows the dismissed row, with the intro hidden" do
      expect(component).to have_css("#{expanded}.tw\\:hidden")
      expect(component).to have_css("#{collapsed}:not(.tw\\:hidden)")
      expect(component).to have_css("#{collapsed} h1", text: "Bike Index Marketplace")
      expect(component).to have_button("What makes this different?")
    end
  end
end
