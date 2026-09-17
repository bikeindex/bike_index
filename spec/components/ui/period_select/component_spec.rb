# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::PeriodSelect::Component, type: :component do
  describe ".column_label" do
    it "humanizes created_at" do
      expect(described_class.column_label("created_at")).to eq "created"
      expect(described_class.column_label("last_updated_activities_at")).to eq "last updated activities"
    end
    it "humanizes start_at and end_at" do
      expect(described_class.column_label("start_at")).to eq "starts"
      expect(described_class.column_label("end_at")).to eq "ends"
      expect(described_class.column_label("subscription_start_at")).to eq "subscription starts"
      expect(described_class.column_label("subscription_end_at")).to eq "subscription ends"
    end
    it "humanizes needs_renewal_at" do
      expect(described_class.column_label("needs_renewal_at")).to eq "need renewal"
    end
    it "humanizes request_at" do
      expect(described_class.column_label("request_at")).to eq "requested"
    end
  end

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
