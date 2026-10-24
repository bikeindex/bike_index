require "rails_helper"

RSpec.describe Counts do
  let(:redis) { Redis.new }
  before { redis.expire(Counts::STORAGE_KEY, 0) }

  describe "counts_keys" do
    it "has things" do
      expect(Counts.count_keys.count).to eq 7
      expect(Counts.count_keys).to include("total_bikes")
      expect(Counts.count_keys).to include("organizations")
    end
  end

  describe "retrieve_many" do
    it "reads the keys in order, with 0 for a missing one" do
      Counts.assign_for("recoveries", 12)
      Counts.assign_for("organizations", 3)
      expect(Counts.retrieve_many("organizations", "recoveries_value", "recoveries")).to eq [3, 0, 12]
    end
  end

  context "total_bikes" do
    it "saves things to redis" do
      Counts.assign_total_bikes
      expect(redis.hget(Counts::STORAGE_KEY, "total_bikes")).to eq "0"
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
        Date.current.to_s => 1
      }
    end
    it "saves the thing" do
      expect(Counts.week_creation_chart).to be_nil # Ensure we aren't throwing errors with nil
      Counts.assign_week_creation_chart
      expect(Counts.week_creation_chart.keys.count).to eq 7
      expect(Counts.week_creation_chart).to eq target
    end
  end

  context "logged_searches" do
    let(:request_at) { Time.current.beginning_of_day }
    let!(:bikebook_search) { FactoryBot.create(:logged_search, endpoint: :web_bikebook, serial_normalized: "XXX", request_at:) }
    let!(:serial_search) { FactoryBot.create(:logged_search, endpoint: :web_bikes, serial_normalized: "XXX", request_at:) }
    let!(:no_serial_search) { FactoryBot.create(:logged_search, endpoint: :api_v3_bikes, request_at:) }
    let!(:ebike_rules_search) { FactoryBot.create(:logged_search, endpoint: :web_ebike_rules, request_at:) }
    let!(:marketplace_search) { FactoryBot.create(:logged_search, endpoint: :web_marketplace, request_at:) }
    let!(:marketplace_serial_search) { FactoryBot.create(:logged_search, endpoint: :web_marketplace, serial_normalized: "XXX", request_at:) }
    let!(:marketplace_count_search) { FactoryBot.create(:logged_search, endpoint: :web_marketplace_count, request_at:) }
    let!(:organized_search) { FactoryBot.create(:logged_search, endpoint: :org_bikes, request_at:) }
    let!(:organized_serial_search) { FactoryBot.create(:logged_search, endpoint: :org_impounded, serial_normalized: "XXX", request_at:) }
    let!(:yesterday_search) { FactoryBot.create(:logged_search, endpoint: :web_bikebook, request_at: request_at - 1.minute) }
    let!(:earlier_search) { FactoryBot.create(:logged_search, endpoint: :web_marketplace, request_at: request_at - 1.day - 1.minute) }
    let(:empty_counts) { Counts::LOGGED_SEARCH_KINDS.to_h { [it, 0] } }

    it "stores yesterday's and today's counts" do
      dates = [Date.current - 2.days, Date.yesterday, Date.current]
      expect(Counts.logged_searches(dates)).to eq(dates.to_h { [it, empty_counts] })
      Counts.assign_logged_searches
      expect(Counts.logged_searches(dates)).to eq(
        Date.current - 2.days => empty_counts,
        Date.yesterday => empty_counts.merge("web_bikebook" => 1),
        Date.current => {"web_bikebook" => 1, "web_ebike_rules" => 1, "organized" => 1, "organized_serial" => 1,
                         "user" => 1, "user_serial" => 1, "web_marketplace" => 2}
      )
    end

    it "stores the counts for the passed dates" do
      Counts.assign_logged_searches([Date.current - 2.days])
      expect(Counts.logged_searches([Date.current - 2.days, Date.yesterday])).to eq(
        Date.current - 2.days => empty_counts.merge("web_marketplace" => 1),
        Date.yesterday => empty_counts
      )
    end
  end

  context "recoveries" do
    let!(:recovered_bike) { FactoryBot.create(:stolen_record_recovered, recovered_at: Time.current - 1.day) }
    it "returns constant" do
      expect(StolenRecord.recovered.count).to eq 1
      expect(Counts.assign_recoveries).to eq 2042
      expect(Counts.assign_recoveries_value).to eq Counts.recovery_average_value * 2042
      expect(Counts.recoveries_value).to eq Counts.recovery_average_value * 2042
    end
  end
end
