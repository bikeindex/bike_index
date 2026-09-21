# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::Search::ChartCard::Component, type: :component do
  let(:component) { render_inline(described_class.new(scope:, scope_paths:, stats:)) }
  let(:scope) { nil }
  let(:scope_paths) { {year: "/o/bk/registrations?chart_scope=year", search: "/o/bk/registrations?chart_scope=search"} }
  let(:stats) do
    [ComponentStructs::RegistrationStat.new(key: :registrations, count: 12, previous_count: 6),
      ComponentStructs::RegistrationStat.new(key: :stolen, count: 1)]
  end

  it "defaults to the year scope, captioning it and rendering the stats" do
    expect(component).to have_text("Chart · Last year overview", normalize_ws: true)
    expect(component).to have_link("Last year", href: scope_paths[:year])
    expect(component).to have_css("a[aria-current='true']", text: "Last year")
    expect(component).to have_link("Current search", href: scope_paths[:search])
    expect(component).to have_text("Total registrations")
    expect(component).to have_text("+100%")
    expect(component).to have_text("Reported stolen")
    expect(component).to have_css("dl div", count: 2)
  end

  context "with the search scope" do
    let(:scope) { "search" }

    it "captions the search" do
      expect(component).to have_text("Chart · Current search", normalize_ws: true)
      expect(component).to have_css("a[aria-current='true']", text: "Current search")
    end
  end

  context "with no scope paths" do
    let(:scope) { "search" }
    let(:scope_paths) { {} }

    it "captions its one scope, without the toggle" do
      expect(component).to have_text("Chart · Current search", normalize_ws: true)
      expect(component).to have_no_link("Last year")
    end
  end

  it "collapses from a trigger outside the frame, keeping the open state in the URL" do
    expect(component).to have_css("[data-ui--collapse-param-value='chart_open']", visible: :all)
    expect(component).to have_button("Chart", visible: :all)
    # The frame is what collapses, so nothing loads a chart the card hasn't been opened for
    expect(component).to have_css("[data-ui--collapse-target='content'].tw\\:hidden\\! turbo-frame",
      visible: :all)
    expect(component).to have_no_css("[data-ui--collapse-target='content'] [data-ui--collapse-target='trigger']",
      visible: :all)
  end

  context "with a src" do
    let(:component) { render_inline(described_class.new(src: scope_paths[:year], scope_paths:)) }

    it "renders the lazy frame and its spinner alone" do
      expect(component).to have_css("turbo-frame[loading='lazy'][src='#{scope_paths[:year]}']", visible: :all)
      expect(component).to have_no_text("Total registrations")
    end
  end
end
