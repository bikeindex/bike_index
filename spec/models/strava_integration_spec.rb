require "rails_helper"

RSpec.describe StravaIntegration, type: :model do
  describe "validations" do
    it "requires access_token" do
      strava_integration = FactoryBot.build(:strava_integration, access_token: nil)
      expect(strava_integration).not_to be_valid
      expect(strava_integration.errors[:access_token]).to be_present
    end

    it "requires refresh_token" do
      strava_integration = FactoryBot.build(:strava_integration, refresh_token: nil)
      expect(strava_integration).not_to be_valid
      expect(strava_integration.errors[:refresh_token]).to be_present
    end

    it "raises ArgumentError for invalid status" do
      expect {
        FactoryBot.build(:strava_integration, status: "invalid")
      }.to raise_error(ArgumentError)
    end
  end

  describe "associations" do
    it "belongs to user" do
      strava_integration = FactoryBot.create(:strava_integration)
      expect(strava_integration.user).to be_present
      expect(strava_integration.user).to be_a(User)
    end

    it "has many strava_activities" do
      strava_integration = FactoryBot.create(:strava_integration)
      activity = FactoryBot.create(:strava_activity, strava_integration:)
      expect(strava_integration.strava_activities).to include(activity)
    end

    it "soft deletes, marks disconnected, destroys activities and gear associations but not requests" do
      strava_integration = FactoryBot.create(:strava_integration, status: :synced)
      FactoryBot.create(:strava_activity, strava_integration:)
      FactoryBot.create(:strava_gear_association, strava_integration:)
      FactoryBot.create(:strava_request, strava_integration:)

      expect {
        strava_integration.destroy
      }.to change(StravaActivity, :count).by(-1)
        .and change(StravaGearAssociation, :count).by(-1)
        .and change(StravaRequest, :count).by(0)

      expect(strava_integration.deleted_at).to be_present
      expect(StravaIntegration.count).to eq 0
      expect(StravaIntegration.with_deleted.count).to eq 1
      expect(StravaIntegration.with_deleted.first.status).to eq "disconnected"
    end

    it "allows a new integration for the same user after soft delete" do
      strava_integration = FactoryBot.create(:strava_integration)
      user = strava_integration.user
      strava_integration.destroy

      new_integration = FactoryBot.build(:strava_integration, user:)
      expect(new_integration).to be_valid
    end
  end

  describe "status methods" do
    let(:strava_integration) { FactoryBot.build(:strava_integration) }

    it "syncing?" do
      strava_integration.status = :syncing
      expect(strava_integration.syncing?).to be_truthy
      strava_integration.status = :synced
      expect(strava_integration.syncing?).to be_falsey
    end

    it "synced?" do
      strava_integration.status = :synced
      expect(strava_integration.synced?).to be_truthy
      strava_integration.status = :syncing
      expect(strava_integration.synced?).to be_falsey
    end

    it "error?" do
      strava_integration.status = :error
      expect(strava_integration.error?).to be_truthy
      strava_integration.status = :synced
      expect(strava_integration.error?).to be_falsey
    end

    it "pending?" do
      expect(strava_integration.pending?).to be_truthy
      strava_integration.status = :syncing
      expect(strava_integration.pending?).to be_falsey
    end
  end

  describe "sync_progress_percent" do
    it "returns 0 when athlete_activity_count is nil" do
      strava_integration = FactoryBot.build(:strava_integration, athlete_activity_count: nil)
      expect(strava_integration.sync_progress_percent).to eq(0)
    end

    it "returns 0 when athlete_activity_count is 0" do
      strava_integration = FactoryBot.build(:strava_integration, athlete_activity_count: 0)
      expect(strava_integration.sync_progress_percent).to eq(0)
    end

    it "calculates progress correctly" do
      strava_integration = FactoryBot.build(:strava_integration, athlete_activity_count: 200, activities_downloaded_count: 100)
      expect(strava_integration.sync_progress_percent).to eq(50)
    end

    it "caps at 100" do
      strava_integration = FactoryBot.build(:strava_integration, athlete_activity_count: 100, activities_downloaded_count: 150)
      expect(strava_integration.sync_progress_percent).to eq(100)
    end
  end

  describe "gear_names" do
    it "returns empty array when athlete_gear is blank" do
      strava_integration = FactoryBot.build(:strava_integration, athlete_gear: [])
      expect(strava_integration.gear_names).to eq([])
    end

    it "returns gear names" do
      strava_integration = FactoryBot.build(:strava_integration, :with_athlete)
      expect(strava_integration.gear_names).to eq(["My Road Bike"])
    end
  end

  describe "update_from_athlete_and_stats" do
    let(:strava_integration) { FactoryBot.create(:strava_integration) }
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
      strava_integration.update_from_athlete_and_stats(athlete, stats)
      strava_integration.reload
      expect(strava_integration.athlete_id).to eq("12345678")
      expect(strava_integration.athlete_activity_count).to eq(150)
      expect(strava_integration.athlete_gear.size).to eq(2)
      expect(strava_integration.athlete_gear.first["name"]).to eq("My Road Bike")
    end

    it "handles nil stats" do
      strava_integration.update_from_athlete_and_stats(athlete, nil)
      strava_integration.reload
      expect(strava_integration.athlete_id).to eq("12345678")
      expect(strava_integration.athlete_activity_count).to be_nil
    end
  end

  describe "finish_sync!" do
    it "sets status to synced and updates count" do
      strava_integration = FactoryBot.create(:strava_integration, status: :syncing)
      FactoryBot.create(:strava_activity, strava_integration:)
      strava_integration.finish_sync!
      strava_integration.reload
      expect(strava_integration.status).to eq("synced")
      expect(strava_integration.activities_downloaded_count).to eq(1)
    end
  end
end
