# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::StravaRateLimit::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {rate_limit_json:} }

  context "with nil rate_limit_json" do
    let(:rate_limit_json) { nil }

    it "does not render" do
      expect(instance.render?).to be false
    end
  end

  context "when read limits are more restrictive" do
    let(:rate_limit_json) do
      {"long_limit" => 6000, "long_usage" => 3,
       "short_limit" => 600, "short_usage" => 1,
       "read_long_limit" => 3000, "read_long_usage" => 2500,
       "read_short_limit" => 300, "read_short_usage" => 250}
    end

    it "shows read limits" do
      # short: read has 50 available vs main 599 → shows 50/300
      expect(component.text).to include("50")
      expect(component.text).to include("300")
      expect(component.text).to include("short")
      # daily: read has 500 available vs main 5997 → shows 500/3,000
      expect(component.text).to include("500")
      expect(component.text).to include("daily")
    end
  end

  context "when main limits are more restrictive" do
    let(:rate_limit_json) do
      {"long_limit" => 1000, "long_usage" => 800,
       "short_limit" => 100, "short_usage" => 90,
       "read_long_limit" => 3000, "read_long_usage" => 100,
       "read_short_limit" => 300, "read_short_usage" => 10}
    end

    it "shows main limits" do
      # short: main has 10 available vs read 290 → shows 10/100
      expect(component.text).to include("10")
      expect(component.text).to include("100")
      # daily: main has 200 available vs read 2900 → shows 200/1,000
      expect(component.text).to include("200")
    end
  end
end
