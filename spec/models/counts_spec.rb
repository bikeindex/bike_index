require 'spec_helper'

describe Counts do
  let(:redis) { Redis.new }
  it "saves things to redis" do
    Counts.total_bikes = 42
    expect(redis.hget Counts::COUNTS_KEY, "total_bikes").to eq "42"
  end
end
