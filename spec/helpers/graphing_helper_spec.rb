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
end
