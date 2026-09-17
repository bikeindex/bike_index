# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::PeriodSelect::Component, type: :component do
  describe ".period_label" do
    it "reads what the period's button does" do
      expect(described_class.period_label("month")).to eq "past 30 days"
      expect(described_class.period_label(:next_week)).to eq "next 7 days"
      expect(described_class.period_label("all")).to eq "All"
      # Not a PERIODS key, so it falls back rather than raising
      expect(described_class.period_label("custom")).to eq "custom"
    end
  end
end
