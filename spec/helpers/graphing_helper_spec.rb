# frozen_string_literal: true

require "rails_helper"

RSpec.describe GraphingHelper, type: :helper do
  context "with payment" do
    let(:start_time) { Time.at(1568052985) }
    let(:payment_time) { start_time + 1.minute }
    let!(:payment) { FactoryBot.create(:payment, created_at: payment_time, amount_cents: 1001) }
    before do
      Time.zone = "America/Chicago"
      @time_range = start_time..(start_time + 3.minutes)
    end
    describe "time_range_counts" do
      let(:target_counts) { {" 1:16 PM" => 0, " 1:17 PM" => 1, " 1:18 PM" => 0, " 1:19 PM" => 0} }
      it "returns the thing with want" do
        expect(time_range_counts(collection: Payment.all)).to eq target_counts
      end
    end
    describe "time_range_counts" do
      let(:target_counts) { {" 1:16 PM" => 0, " 1:17 PM" => 10.01, " 1:18 PM" => 0, " 1:19 PM" => 0} }
      it "returns the thing with want" do
        expect(time_range_amounts(collection: Payment.all)).to eq target_counts
      end
    end
  end

  describe "group_by_method" do
    context "hourly" do
      it "returns group_by_minute" do
        expect(group_by_method((Time.current - 1.hour)..Time.current)).to eq :group_by_minute
      end
    end
    context "daily" do
      it "returns group_by_hour" do
        expect(group_by_method((Time.current - 1.day)..Time.current)).to eq :group_by_hour
      end
    end
    context "weekly" do
      it "returns group_by_day" do
        expect(group_by_method((Time.current - 6.days)..Time.current)).to eq :group_by_day
      end
    end
    context "6 months" do
      it "returns group_by_week" do
        expect(group_by_method((Time.current - 6.months)..Time.current)).to eq :group_by_week
      end
    end
    context "2 years" do
      it "returns group_by_month" do
        expect(group_by_method((Time.current - 2.years)..Time.current)).to eq :group_by_month
      end
    end
  end

  describe "group_by_format" do
    let(:end_time) { Time.at(1578268910) } # 2020-01-06 00:01:38 UTC
    let(:time_range) { start_time..end_time }
    context "1 hour" do
      let(:start_time) { end_time - 1.hour }
      it "is hour:minute pm" do
        expect(end_time.in_time_zone("America/New_York").strftime(group_by_format(time_range))).to eq " 7:01 PM"
      end
    end
    context "3 days" do
      let(:start_time) { end_time - 3.days }
      it "is weekday hour pm" do
        expect(end_time.in_time_zone("America/New_York").strftime(group_by_format(time_range))).to eq "Sun 7 PM"
      end
    end
    context "6 days" do
      let(:start_time) { end_time - 10.days }
      it "is weekday month-date" do
        expect(end_time.in_time_zone("America/New_York").strftime(group_by_format(time_range))).to eq "Sun 1-5"
      end
    end
    context "13 months" do
      let(:start_time) { end_time - 13.months }
      it "is year-month" do
        expect(end_time.strftime(group_by_format(time_range))).to eq "2020-1"
      end
    end
  end

  describe "humanized_time_range_column" do
    it "humanizes created_at" do
      expect(humanized_time_range_column("created_at")).to eq "created"
      @period = "all"
      expect(humanized_time_range_column("created_at")).to be_blank
      expect(humanized_time_range_column("created_at", return_value_for_all: true)).to eq "created"
    end
    it "humanizes start_at and end_at" do
      expect(humanized_time_range_column("start_at")).to eq "started"
      expect(humanized_time_range_column("end_at")).to eq "ended"
    end
    it "humanizes needs_renewal_at" do
      expect(humanized_time_range_column("needs_renewal_at")).to eq "needs renewal" # good enough
    end
    it "humanizes subscription_start_at and subscription_end_at" do
      expect(humanized_time_range_column("subscription_start_at")).to eq "subscription started"
      expect(humanized_time_range_column("subscription_end_at")).to eq "subscription ended"
    end
  end

  describe "humanized_time_range" do
    context "standard time range" do
      it "returns period" do
        @period = "week"
        expect(humanized_time_range((Time.current - 1.week)..Time.current)).to eq "in the past week"
      end
      context "week" do
        it "returns period" do
          @period = "all"
          expect(humanized_time_range((Time.current - 1.week)..Time.current)).to be_blank
        end
      end
    end

    context "custom time period" do
      let(:end_time) { Time.at(1578268910) } # 2020-01-06 00:01:38 UTC
      let(:time_range) { start_time..end_time }
      before { @period = "custom" }

      context "45 minute long period" do
        let(:start_time) { end_time - 45.minutes }
        let(:target_html) do
          [
            'from <em class="convertTime preciseTimeSeconds">',
            start_time.strftime("%FT%T%z"),
            '</em> to <em class="convertTime preciseTimeSeconds">',
            end_time.strftime("%FT%T%z") + "</em>"
          ]
        end
        it "returns with preciseTimeSeconds" do
          expect(humanized_time_range(time_range)).to eq "<span>" + target_html.join + "</span>"
        end
      end

      context "2 hour long period" do
        let(:start_time) { end_time - 2.hours }
        let(:target_html) do
          [
            'from <em class="convertTime preciseTime">',
            start_time.strftime("%FT%T%z"),
            '</em> to <em class="convertTime preciseTime">',
            end_time.strftime("%FT%T%z") + "</em>"
          ]
        end
        it "returns time in precise time" do
          expect(humanized_time_range(time_range)).to eq "<span>" + target_html.join + "</span>"
        end
        context "ending now" do
          let(:end_time) { Time.current - 1.minute } # Because we send time by minute
          let(:current_target_html) { target_html.slice(0, 2) + ["</em> to <em>now</em>"] }
          it "returns time in precise time" do
            expect(humanized_time_range(time_range)).to eq "<span>" + current_target_html.join + "</span>"
          end
        end
      end

      context "week long period" do
        let(:start_time) { end_time - 7.days }
        let(:target_html) do
          [
            'from <em class="convertTime ">',
            start_time.strftime("%FT%T%z"),
            '</em> to <em class="convertTime ">',
            end_time.strftime("%FT%T%z") + "</em>"
          ]
        end
        it "returns with preciseTimeSeconds" do
          expect(humanized_time_range(time_range)).to eq "<span>" + target_html.join + "</span>"
        end
      end
    end
  end
end
