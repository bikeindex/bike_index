# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Chart::Component, type: :component do
  let(:time_range) { 1.week.ago..Time.current }
  let(:instance) { described_class.new(series: [{name: "Test", data: {}}], time_range:) }

  it "renders with default colors" do
    script_content = render_inline(instance).css("script").text
    expect(script_content).to be_present
    described_class::COLORS.each do |color|
      expect(script_content).to include(color)
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
    before { Time.zone = "America/Chicago" }

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
