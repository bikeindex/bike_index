# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::TimeRange::Component, type: :component do
  let(:time_range) { (Time.current - 1.week)..Time.current }

  def render_component(period:, range: time_range)
    render_inline(described_class.new(time_range: range, period:))
  end

  context "a named period" do
    it "names it in prose" do
      expect(render_component(period: "week").to_html.strip).to eq "in the past week"
      expect(render_component(period: "next_week").to_html.strip).to eq "in the next week"
    end
  end

  context "all, or no period" do
    it "renders nothing" do
      expect(render_component(period: "all").to_html).to be_blank
      expect(render_component(period: nil).to_html).to be_blank
    end
  end

  context "custom" do
    it "renders the endpoints, the last as now" do
      html = render_component(period: "custom")
      expect(html.css("em").length).to eq 2
      expect(html.css("em").last.text.strip).to eq "now"
      expect(html.css("em span.localizeTime").length).to eq 1
    end

    it "renders a finished range's end as a time" do
      range = (Time.current - 2.weeks)..(Time.current - 1.week)
      html = render_component(period: "custom", range:)
      expect(html.css("em span.localizeTime").length).to eq 2
    end

    # A minute-bucketed range's endpoints differ only in their seconds
    it "asks for seconds precision on a short range" do
      range = (Time.current - 30.minutes)..(Time.current - 10.minutes)
      html = render_component(period: "custom", range:)
      expect(html.css("span.preciseTimeSeconds").length).to eq 2
    end
  end
end
