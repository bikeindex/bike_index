# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::PeriodSelect::Component, type: :component do
  describe ".column_label" do
    it "reads the column as prose" do
      expect(described_class.column_label("created_at")).to eq "created"
      expect(described_class.column_label("last_updated_activities_at")).to eq "last updated activities"
      expect(described_class.column_label("start_at")).to eq "starts"
      expect(described_class.column_label("subscription_end_at")).to eq "subscription ends"
      expect(described_class.column_label("request_at")).to eq "requested"
      # Not a duplicate of request_at - the \z anchor is what keeps this one "requested"
      expect(described_class.column_label("requested_at")).to eq "requested"
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

  describe "alignment" do
    let(:component) do
      with_request_url("/admin/bikes") do
        render_inline(described_class.new(period: "all", start_time: Time.current - 1.year, end_time: Time.current, align_start:))
      end
    end
    let(:align_start) { false }

    it "sits the buttons in the page corner" do
      expect(component).to have_css("[role='group'].tw\\:justify-end")
    end

    context "with align_start" do
      let(:align_start) { true }

      it "starts the buttons beside whatever labels them" do
        expect(component).to have_css("[role='group'].tw\\:justify-start")
        expect(component).not_to have_css("[role='group'].tw\\:justify-end")
      end
    end
  end
end
