require "rails_helper"

RSpec.describe GraphingHelper, type: :helper do
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

  describe "humanized_time_range" do
    context "standard time range" do
      it "returns period" do
        @period = "week"
        expect(humanized_time_range((Time.current - 1.week)..Time.current)).to eq "in the past week"
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
            end_time.strftime("%FT%T%z") + '</em>'
          ].join
        end
        it "returns with preciseTimeSeconds" do
          expect(humanized_time_range(time_range)).to eq "<span>" + target_html + "</span>"
        end
      end

      context "2 hour long period" do
        let(:start_time) { end_time - 2.hours }
        let(:target_html) do
          [
            'from <em class="convertTime preciseTime">',
            start_time.strftime("%FT%T%z"),
            '</em> to <em class="convertTime preciseTime">',
            end_time.strftime("%FT%T%z") + '</em>'
          ].join
        end
        it "returns time in precise time" do
          expect(humanized_time_range(time_range)).to eq "<span>" + target_html + "</span>"
        end
      end

      context "week long period" do
        let(:start_time) { end_time - 7.days }
        let(:target_html) do
          [
            'from <em class="convertTime ">',
            start_time.strftime("%FT%T%z"),
            '</em> to <em class="convertTime ">',
            end_time.strftime("%FT%T%z") + '</em>'
          ].join
        end
        it "returns with preciseTimeSeconds" do
          expect(humanized_time_range(time_range)).to eq "<span>" + target_html + "</span>"
        end
      end
    end
  end
end
