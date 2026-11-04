# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Chart::Component, type: :component do
  let(:time_range) { 1.week.ago..Time.current }
  let(:instance) { described_class.new(series: [{name: "Test", data: {}}], time_range:) }

  it "renders the default colors, no legend for a single series, and its own element id each time" do
    rendered = render_inline(instance)
    script_content = rendered.css("script").text
    described_class::COLORS.each { |color| expect(script_content).to include(color) }
    expect(rendered.css("[data-chart-legend]")).to be_blank

    rerendered = render_inline(described_class.new(series: [{name: "Test", data: {}}], time_range:))
    expect(rerendered.at_css("[id^='chart-']")["id"]).not_to eq rendered.at_css("[id^='chart-']")["id"]

    # Several series keep the legend that tells them apart
    several = render_inline(described_class.new(series: [{name: "A", data: {}}, {name: "B", data: {}}]))
    expect(several.css("[data-chart-legend]")).to be_present
  end

  describe "library" do
    let(:series) { {"A" => 1, "B" => 2} }

    it "keeps a pie's legend unless its library turns it off" do
      bottom = render_inline(described_class.new(series:, kind: :pie, library: {plugins: {legend: {position: "bottom"}}}))
      expect(bottom.css("[data-chart-legend]").first["class"]).to include("tw:order-1")

      off = render_inline(described_class.new(series:, kind: :pie, library: {plugins: {legend: false}}))
      expect(off.css("[data-chart-legend]")).to be_blank
    end
  end

  context "with custom colors" do
    let(:custom_colors) { %w[#111111 #222222] }
    let(:instance) { described_class.new(series: [{name: "Test", data: {}}], time_range:, colors: custom_colors) }
    it "renders with custom colors" do
      script_content = render_inline(instance).css("script").text
      custom_colors.each { |color| expect(script_content).to include(color) }
      expect(script_content).not_to include(described_class::COLORS.last)
    end
  end

  describe "time_range" do
    let(:start_time) { Time.at(1568052985) }
    let(:time_range) { start_time..(start_time + 3.minutes) }
    let(:buckets) { %([[" 1:16 PM",0],[" 1:17 PM",0],[" 1:18 PM",0],[" 1:19 PM",0]]) }
    around { |example| Time.use_zone("America/Chicago") { example.run } }

    it "fills the buckets a series is missing" do
      expect(render_inline(instance).css("script").text).to include(buckets)
      # a bare grouped hash, rather than named series, fills the same way
      bare = described_class.new(series: {}, time_range:)
      expect(render_inline(bare).css("script").text).to include(buckets)
    end

    context "without one" do
      let(:instance) { described_class.new(series: [{name: "Test", data: {}}]) }
      it "renders the series as passed" do
        expect(render_inline(instance).css("script").text).to include(%("data":[]))
      end
    end

    context "with a path to fetch" do
      let(:instance) { described_class.new(series: "/admin/graphs/variable", time_range:) }
      it "leaves the path for the browser" do
        expect(render_inline(instance).css("script").text).to include(%("/admin/graphs/variable"))
      end
    end
  end
end
