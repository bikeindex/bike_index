require "rails_helper"

RSpec.describe Counts, type: :model do
  let(:redis) { Redis.new }
  before { redis.expire(Counts::STOREAGE_KEY, 0) }

  context "total_bikes" do
    it "saves things to redis" do
      Counts.assign_total_bikes
      expect(redis.hget Counts::STOREAGE_KEY, "total_bikes").to eq "0"
      expect(Counts.total_bikes).to eq 0
    end
  end

  context "week_creation_chart" do
    let!(:bike) { FactoryBot.create(:bike) }
    let(:target) { { "#{Date.today}" => 1 } }
    it "saves the thing" do
      expect(Counts.week_creation_chart).to be_nil # Ensure we aren't throwing errors
      Counts.assign_week_creation_chart
      expect(Counts.week_creation_chart).to eq target
    end
  end

  context "recoveries" do
    let!(:recovered_bike) { FactoryBot.create(:stolen_record_recovered, date_recovered: Time.now - 1.day) }
    it "returns constant" do
      expect(StolenRecord.recovered.count).to eq 1
      expect(Counts.assign_recoveries).to eq 2042
      expect(Counts.assign_recoveries_value).to eq Counts.recovery_average_value * 2042
      expect(Counts.recoveries_value).to eq Counts.recovery_average_value * 2042
    end
  end
end
