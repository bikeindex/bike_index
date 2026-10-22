require "rails_helper"

RSpec.describe BikeJobs::PrepareDuplicateReviewJob, type: :job do
  let(:finder) { BikeDuplicatesServices::Finder }

  after { RedisPool.conn { it.del(finder::SNAPSHOT_KEY, finder::PREPARING_KEY) } }

  it "stores the groups and their cues for the dashboard" do
    manufacturer = FactoryBot.create(:manufacturer)
    bikes = Array.new(2) { FactoryBot.create(:bike, :with_ownership, manufacturer:, serial_number: "EN 14764 A1") }
    expect(finder.fetch_group_snapshot).to be_nil

    described_class.new.perform
    group = finder.fetch_group_snapshot[:groups].sole
    expect(group["bike_ids"]).to match_array(bikes.map(&:id))
    expect(group["first_at"]).to be_a(ActiveSupport::TimeWithZone)
    expect(group["cues"].find { it.key == "standard_marking" }.color).to eq :warning
    expect(RedisPool.conn { it.get(finder::PREPARING_KEY) }).to be_nil
  end
end
