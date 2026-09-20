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

  describe "rendering" do
    let(:component) do
      with_request_url("/admin/bikes") do
        render_inline(described_class.new(period:, start_time: Time.current - 1.week,
          end_time: Time.current, **options))
      end
    end
    let(:period) { "week" }
    let(:options) { {} }
    let(:small) { UI::Button::Component::SIZES[:sm] }

    it "navigates, each period its own link, sized small" do
      expect(component).to have_css("a[data-period='week'][data-active='true']", class: small.split)
      expect(component).to have_button("custom", class: small.split)
      expect(component).not_to have_css("input[type=radio]", visible: :all)
    end

    context "with size: :md" do
      let(:options) { {size: :md} }
      let(:medium) { UI::Button::Component::SIZES[:md] }

      it "sizes the links and the custom button medium instead" do
        expect(component).to have_css("a[data-period='week']", class: medium.split)
        expect(component).to have_button("custom", class: medium.split)
      end
    end

    context "with a size it doesn't have" do
      let(:options) { {size: :xl} }

      it "raises" do
        expect { component }.to raise_error(ArgumentError, /size/)
      end
    end

    context "with a form" do
      let(:options) { {form: "search_form"} }

      it "submits that form instead, the checked radio carrying the period" do
        expect(component).to have_css("input[type=radio][name='period'][value='week'][form='search_form']", visible: :all, count: 1)
        expect(component).to have_css("input[type=radio][value='week'][checked]", visible: :all)
        expect(component).not_to have_css("a[data-period]")
        expect(component).to have_css("label", class: small.split, visible: :all)
        # Picking one closes the custom panel it replaces, and submits the search
        expect(component).to have_css(
          "input[type=radio][value='week'][data-action='change->ui--collapse#hide change->ui--period-select#rangePicked']",
          visible: :all
        )
        # No chip stands for a custom range, so there's nothing to outrank the one picked
        expect(component).not_to have_css("input[type=hidden][name='period']", visible: :all)
      end

      it "carries each period's range, for the custom panel to open on" do
        year = 1.year.ago.beginning_of_day.strftime(described_class::INPUT_TIME_FORMAT)
        expect(component).to have_css("input[value='year'][data-start-time='#{year}']", visible: :all)
        # `all` starts at the controller's own earliest_period_date, which the chip can't know
        expect(component).to have_css("input[value='all']:not([data-start-time])", visible: :all)
      end

      context "over a custom range" do
        let(:period) { "custom" }

        it "carries the custom period in a hidden field, for ui--period-select to disable" do
          expect(component).to have_css(
            "input[type=hidden][name='period'][value='custom'][form='search_form'][data-ui--period-select-target='customPeriod']",
            visible: :all
          )
        end
      end
    end
  end
end
