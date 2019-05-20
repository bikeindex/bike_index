require "spec_helper"

describe Counts do
  let(:redis) { Redis.new }
  context "total_bikes" do
    it "saves things to redis" do
      Counts.assign_total_bikes
      expect(redis.hget Counts::STOREAGE_KEY, "total_bikes").to eq "0"
      expect(Counts.total_bikes).to eq 0
    end
  end
  context ""
end
