# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::TimeRange::Component, type: :component do
  let(:time_range) { (Time.current - 1.week)..Time.current }

  def render_component(period:, range: time_range)
    render_inline(described_class.new(time_range: range, period:))
  end

  context "a named period, all, or none" do
    it "names a named period in prose, and renders nothing otherwise" do
      expect(render_component(period: "week").to_html.strip).to eq "in the past week"
      expect(render_component(period: "next_week").to_html.strip).to eq "in the next week"
      expect(render_component(period: "all").to_html).to be_blank
      expect(render_component(period: nil).to_html).to be_blank
    end
  end

  context "custom" do
    let(:now) { Time.current }

    it "renders the endpoints at the chart bucket's precision, a recent end as now" do
      ongoing = render_component(period: "custom")
      expect(ongoing.css("em").last.text.strip).to eq "now"
      expect(ongoing.css("em span.localizeTime").length).to eq 1

      hour = render_component(period: "custom", range: (now - 2.hours)..(now - 1.hour))
      expect(hour.css("em span.preciseTimeSeconds").length).to eq 2

      longer = render_component(period: "custom", range: (now - 2.hours - 1.minute)..(now - 1.hour))
      expect(longer.css("span.preciseTimeSeconds")).to be_empty
      expect(longer.css("em span.preciseTime").length).to eq 2
    end
  end
end
