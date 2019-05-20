require "spec_helper"

describe Counts do
  let(:redis) { Redis.new }
  before { redis.expire(Counts::STOREAGE_KEY, 0) }

  context "total_bikes" do
    it "saves things to redis" do
      Counts.assign_total_bikes
      expect(redis.hget Counts::STOREAGE_KEY, "total_bikes").to eq "0"
      expect(Counts.total_bikes).to eq 0
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
