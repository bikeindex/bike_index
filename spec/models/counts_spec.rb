require "rails_helper"

RSpec.describe Counts, type: :model do
  let(:redis) { Redis.new }
  before { redis.del(Counts::STOREAGE_KEY) }

  context "total_bikes" do
    it "saves things to redis" do
      Counts.assign_total_bikes
      expect(redis.hget Counts::STOREAGE_KEY, "total_bikes").to eq "0"
      expect(Counts.total_bikes).to eq 0
    end
  end

  context "week_creation_chart" do
    let!(:bike) { FactoryBot.create(:bike) }
    let!(:bike_first) { FactoryBot.create(:bike, created_at: (Time.current - 6.days).beginning_of_day + 1.minute) }
    let(:target) do
      {
        (Date.current - 6.days).to_s => 1,
        (Date.current - 5.days).to_s => 0,
        (Date.current - 4.days).to_s => 0,
        (Date.current - 3.days).to_s => 0,
        (Date.current - 2.days).to_s => 0,
        (Date.current - 1.days).to_s => 0,
        Date.current.to_s => 1,
      }
    end
    it "saves the thing" do
      expect(Counts.week_creation_chart).to be_nil # Ensure we aren't throwing errors with nil
      Counts.assign_week_creation_chart
      expect(Counts.week_creation_chart.keys.count).to eq 7
      expect(Counts.week_creation_chart).to eq target
    end
  end

  context "recoveries" do
    let!(:recovered_bike) { FactoryBot.create(:stolen_record_recovered, date_recovered: Time.current - 1.day) }
    it "returns constant" do
      expect(StolenRecord.recovered.count).to eq 1
      expect(Counts.assign_recoveries).to eq 2042
      expect(Counts.assign_recoveries_value).to eq Counts.recovery_average_value * 2042
      expect(Counts.recoveries_value).to eq Counts.recovery_average_value * 2042
    end
  end
end
