require "rails_helper"

RSpec.describe StravaIntegration, type: :model do
  describe "validations" do
    it "requires access_token" do
      si = FactoryBot.build(:strava_integration, access_token: nil)
      expect(si).not_to be_valid
      expect(si.errors[:access_token]).to be_present
    end

    it "requires refresh_token" do
      si = FactoryBot.build(:strava_integration, refresh_token: nil)
      expect(si).not_to be_valid
      expect(si.errors[:refresh_token]).to be_present
    end

    it "raises ArgumentError for invalid status" do
      expect {
        FactoryBot.build(:strava_integration, status: "invalid")
      }.to raise_error(ArgumentError)
    end
  end

  describe "enum" do
    it "defines expected statuses" do
      expect(StravaIntegration.statuses.keys).to eq(%w[pending syncing synced error])
    end
  end

  describe "associations" do
    it "belongs to user" do
      si = FactoryBot.create(:strava_integration)
      expect(si.user).to be_present
      expect(si.user).to be_a(User)
    end

    it "has many strava_activities" do
      si = FactoryBot.create(:strava_integration)
      activity = FactoryBot.create(:strava_activity, strava_integration: si)
      expect(si.strava_activities).to include(activity)
    end

    it "destroys strava_activities when destroyed" do
      si = FactoryBot.create(:strava_integration)
      FactoryBot.create(:strava_activity, strava_integration: si)
      expect {
        si.destroy
      }.to change(StravaActivity, :count).by(-1)
    end
  end

  describe "status methods" do
    let(:si) { FactoryBot.build(:strava_integration) }

    it "syncing?" do
      si.status = :syncing
      expect(si.syncing?).to be_truthy
      si.status = :synced
      expect(si.syncing?).to be_falsey
    end

    it "synced?" do
      si.status = :synced
      expect(si.synced?).to be_truthy
      si.status = :syncing
      expect(si.synced?).to be_falsey
    end

    it "error?" do
      si.status = :error
      expect(si.error?).to be_truthy
      si.status = :synced
      expect(si.error?).to be_falsey
    end

    it "pending?" do
      expect(si.pending?).to be_truthy
      si.status = :syncing
      expect(si.pending?).to be_falsey
    end
  end

  describe "sync_progress_percent" do
    it "returns 0 when athlete_activity_count is nil" do
      si = FactoryBot.build(:strava_integration, athlete_activity_count: nil)
      expect(si.sync_progress_percent).to eq(0)
    end

    it "returns 0 when athlete_activity_count is 0" do
      si = FactoryBot.build(:strava_integration, athlete_activity_count: 0)
      expect(si.sync_progress_percent).to eq(0)
    end

    it "calculates progress correctly" do
      si = FactoryBot.build(:strava_integration, athlete_activity_count: 200, activities_downloaded_count: 100)
      expect(si.sync_progress_percent).to eq(50)
    end

    it "caps at 100" do
      si = FactoryBot.build(:strava_integration, athlete_activity_count: 100, activities_downloaded_count: 150)
      expect(si.sync_progress_percent).to eq(100)
    end
  end

  describe "gear_names" do
    it "returns empty array when athlete_gear is blank" do
      si = FactoryBot.build(:strava_integration, athlete_gear: [])
      expect(si.gear_names).to eq([])
    end

    it "returns gear names" do
      si = FactoryBot.build(:strava_integration, :with_athlete)
      expect(si.gear_names).to eq(["My Road Bike"])
    end
  end

  describe "update_from_athlete_and_stats" do
    let(:si) { FactoryBot.create(:strava_integration) }
    let(:athlete) do
      {"id" => 12345678,
       "bikes" => [{"id" => "b1234", "name" => "My Road Bike", "primary" => true, "distance" => 50000.0, "resource_state" => 2}],
       "shoes" => [{"id" => "g9012", "name" => "Running Shoes", "primary" => true, "distance" => 10000.0, "resource_state" => 2}]}
    end
    let(:stats) do
      {"all_ride_totals" => {"count" => 100},
       "all_run_totals" => {"count" => 40},
       "all_swim_totals" => {"count" => 10}}
    end

    it "updates athlete_id, activity_count, and gear" do
      si.update_from_athlete_and_stats(athlete, stats)
      si.reload
      expect(si.athlete_id).to eq("12345678")
      expect(si.athlete_activity_count).to eq(150)
      expect(si.athlete_gear.size).to eq(2)
      expect(si.athlete_gear.first["name"]).to eq("My Road Bike")
    end

    it "handles nil stats" do
      si.update_from_athlete_and_stats(athlete, nil)
      si.reload
      expect(si.athlete_id).to eq("12345678")
      expect(si.athlete_activity_count).to be_nil
    end
  end

  describe "finish_sync!" do
    it "sets status to synced and updates count" do
      si = FactoryBot.create(:strava_integration, status: :syncing)
      FactoryBot.create(:strava_activity, strava_integration: si)
      si.finish_sync!
      si.reload
      expect(si.status).to eq("synced")
      expect(si.activities_downloaded_count).to eq(1)
    end
  end
end
