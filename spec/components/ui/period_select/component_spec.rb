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

  describe "form" do
    let(:component) do
      with_request_url("/admin/bikes") do
        render_inline(described_class.new(period: "week", start_time: Time.current - 1.week,
          end_time: Time.current, form:))
      end
    end
    let(:form) { nil }

    it "navigates, each period its own link" do
      expect(component).to have_css("a[data-period='week'][data-active='true']")
      expect(component).not_to have_css("input[type=radio]", visible: :all)
    end

    context "with a form" do
      let(:form) { "search_form" }

      it "submits that form instead, the checked radio carrying the period" do
        expect(component).to have_css("input[type=radio][name='period'][value='week'][form='search_form']", visible: :all, count: 1)
        expect(component).to have_css("input[type=radio][value='week'][checked]", visible: :all)
        expect(component).not_to have_css("a[data-period]")
        # No chip stands for a custom range, so a search would drop it
        expect(component).not_to have_css("input[type=hidden][name='period']", visible: :all)
      end
    end

    context "with a form, over a custom range" do
      let(:form) { "search_form" }
      let(:component) do
        with_request_url("/admin/bikes") do
          render_inline(described_class.new(period: "custom", start_time: Time.current - 1.week,
            end_time: Time.current, form:))
        end
      end

      it "carries the custom period in a hidden field" do
        expect(component).to have_css("input[type=hidden][name='period'][value='custom'][form='search_form']", visible: :all)
      end
    end
  end
end
