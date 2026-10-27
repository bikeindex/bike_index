require "rails_helper"

RSpec.describe BikeJobs::PrepareDuplicateReviewJob, type: :job do
  let(:finder) { BikeDuplicatesServices::Finder }

  after { RedisPool.conn { it.del(finder::SNAPSHOT_KEY, finder::PREPARING_KEY) } }

  it "stores the groups and their cue keys for the dashboard, then releases its claim" do
    manufacturer = FactoryBot.create(:manufacturer)
    bikes = Array.new(2) { FactoryBot.create(:bike, :with_ownership, manufacturer:, serial_number: "EN 14764 A1") }
    expect(finder.fetch_group_snapshot).to be_nil
    claim = RedisPool.conn { it.get(finder::PREPARING_KEY) }
    expect(described_class.jobs.map { it["args"] }).to eq [[claim]]

    described_class.new.perform(claim)
    group = finder.fetch_group_snapshot[:groups].sole
    expect(group["bike_ids"]).to match_array(bikes.map(&:id))
    expect(group["first_at"]).to eq bikes.first.created_at.to_i
    expect(group["cue_keys"]).to eq ["standard_marking"]
    expect(RedisPool.conn { it.get(finder::PREPARING_KEY) }).to be_nil
  end

  it "leaves a newer job's claim in place" do
    RedisPool.conn { it.set(finder::PREPARING_KEY, "newer") }
    described_class.new.perform("expired")
    expect(RedisPool.conn { it.get(finder::PREPARING_KEY) }).to eq "newer"
  end
end
