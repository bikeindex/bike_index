# frozen_string_literal: true

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

    it "soft deletes, marks disconnected, destroys activities and gear but not requests" do
      strava_integration = FactoryBot.create(:strava_integration, status: :synced)
      FactoryBot.create(:strava_activity, strava_integration:)
      FactoryBot.create(:strava_gear, strava_integration:)
      FactoryBot.create(:strava_request, strava_integration:)

      expect {
        strava_integration.destroy
      }.to change(StravaActivity, :count).by(-1)
        .and change(StravaGear, :count).by(-1)
        .and change(StravaRequest, :count).by(0)

      expect(strava_integration.deleted_at).to be_present
      expect(StravaIntegration.count).to eq 0
      expect(StravaIntegration.with_deleted.count).to eq 1
      deleted_integration = StravaIntegration.with_deleted.first
      expect(deleted_integration.access_token).to eq ""
      expect(deleted_integration.refresh_token).to eq ""
      expect(deleted_integration.token_expires_at).to be_nil
      expect(deleted_integration.activities_downloaded_count).to eq 0
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
    it "returns empty array when no strava_gears" do
      strava_integration = FactoryBot.create(:strava_integration)
      expect(strava_integration.gear_names).to eq([])
    end

    it "returns gear names" do
      strava_integration = FactoryBot.create(:strava_integration, :with_gear)
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

    it "updates athlete_id, activity_count, creates gear records, and sets status to syncing" do
      strava_integration.update_from_athlete_and_stats(athlete, stats)
      strava_integration.reload
      expect(strava_integration.athlete_id).to eq("12345678")
      expect(strava_integration.athlete_activity_count).to eq(150)
      expect(strava_integration.strava_gears.count).to eq(2)
      expect(strava_integration.strava_gears.bikes.first.strava_gear_name).to eq("My Road Bike")
      expect(strava_integration.strava_gears.shoes.first.strava_gear_name).to eq("Running Shoes")
      expect(strava_integration.status).to eq("syncing")
    end

    it "handles nil stats" do
      strava_integration.update_from_athlete_and_stats(athlete, nil)
      strava_integration.reload
      expect(strava_integration.athlete_id).to eq("12345678")
      expect(strava_integration.athlete_activity_count).to be_nil
    end

    it "upserts existing gear records" do
      strava_integration.update_from_athlete_and_stats(athlete, stats)
      expect(strava_integration.strava_gears.count).to eq(2)

      StravaGear.update_from_strava(strava_integration,
        {"id" => "b1234", "name" => "Renamed Road Bike", "gear_type" => "bike", "primary" => true, "distance" => 60000.0, "resource_state" => 2})
      expect(strava_integration.strava_gears.count).to eq(2)
      expect(strava_integration.strava_gears.find_by(strava_gear_id: "b1234").strava_gear_name).to eq("Renamed Road Bike")
    end
  end

  describe "gear_ids_to_request" do
    let(:strava_integration) { FactoryBot.create(:strava_integration) }

    it "returns un_enriched gear ids" do
      FactoryBot.create(:strava_gear, strava_integration:, strava_gear_id: "b1234",
        strava_data: {"resource_state" => 2})
      FactoryBot.create(:strava_gear, strava_integration:, strava_gear_id: "b5678",
        strava_data: {"resource_state" => 3})
      expect(strava_integration.gear_ids_to_request).to eq(["b1234"])
    end

    it "includes unknown gear ids from activities" do
      FactoryBot.create(:strava_activity, strava_integration:, gear_id: "b9999")
      expect(strava_integration.gear_ids_to_request).to include("b9999")
    end

    it "deduplicates ids" do
      FactoryBot.create(:strava_gear, strava_integration:, strava_gear_id: "b1234",
        strava_data: {"resource_state" => 2})
      FactoryBot.create(:strava_activity, strava_integration:, gear_id: "b1234")
      expect(strava_integration.gear_ids_to_request).to eq(["b1234"])
    end
  end

  describe "enqueue_gear_requests" do
    let(:strava_integration) { FactoryBot.create(:strava_integration) }
    before { StravaRequest.destroy_all }

    it "creates fetch_gear requests for un_enriched gear" do
      FactoryBot.create(:strava_gear, strava_integration:, strava_gear_id: "b1234",
        strava_data: {"resource_state" => 2})
      FactoryBot.create(:strava_gear, strava_integration:, strava_gear_id: "b5678",
        strava_data: {"resource_state" => 3})
      strava_integration.send(:enqueue_gear_requests)
      gear_requests = StravaRequest.where(strava_integration_id: strava_integration.id, request_type: :fetch_gear)
      expect(gear_requests.count).to eq(1)
      expect(gear_requests.first.parameters["strava_gear_id"]).to eq("b1234")
    end

    it "creates fetch_gear requests for unknown gear ids" do
      FactoryBot.create(:strava_activity, strava_integration:, gear_id: "b9999")
      strava_integration.send(:enqueue_gear_requests)
      gear_requests = StravaRequest.where(strava_integration_id: strava_integration.id, request_type: :fetch_gear)
      expect(gear_requests.count).to eq(1)
      expect(gear_requests.first.parameters["strava_gear_id"]).to eq("b9999")
    end

    it "does not create duplicate requests" do
      FactoryBot.create(:strava_gear, strava_integration:, strava_gear_id: "b1234",
        strava_data: {"resource_state" => 2})
      strava_integration.send(:enqueue_gear_requests)
      strava_integration.send(:enqueue_gear_requests)
      gear_requests = StravaRequest.where(strava_integration_id: strava_integration.id, request_type: :fetch_gear)
      expect(gear_requests.count).to eq(1)
    end
  end

  describe "update_sync_status" do
    let(:strava_integration) { FactoryBot.create(:strava_integration, status: :syncing) }

    it "sets status to synced when no unprocessed requests and all cycling enriched" do
      FactoryBot.create(:strava_activity, strava_integration:, activity_type: "Ride", segment_locations: {})
      strava_integration.update_sync_status
      strava_integration.reload
      expect(strava_integration.status).to eq("synced")
      expect(strava_integration.activities_downloaded_count).to eq(1)
    end

    it "stays syncing when unprocessed list_activities requests remain" do
      FactoryBot.create(:strava_activity, strava_integration:, activity_type: "Ride", segment_locations: {})
      FactoryBot.create(:strava_request, strava_integration:, request_type: :list_activities)
      strava_integration.update_sync_status
      strava_integration.reload
      expect(strava_integration.status).to eq("syncing")
      expect(strava_integration.activities_downloaded_count).to eq(1)
    end

    it "enqueues detail requests when cycling activities are not enriched" do
      FactoryBot.create(:strava_activity, strava_integration:, activity_type: "Ride", segment_locations: nil)
      strava_integration.update_sync_status
      strava_integration.reload
      expect(strava_integration.status).to eq("synced")
      expect(StravaRequest.where(strava_integration_id: strava_integration.id, request_type: :fetch_activity).count).to eq(1)
    end

    it "updates gear total distances and enqueues gear requests when list_activities done" do
      strava_gear = FactoryBot.create(:strava_gear, strava_integration:, strava_gear_id: "b1234",
        strava_data: {"resource_state" => 3})
      FactoryBot.create(:strava_gear, strava_integration:, strava_gear_id: "b5678",
        strava_data: {"resource_state" => 2})
      FactoryBot.create(:strava_activity, strava_integration:, gear_id: "b1234",
        activity_type: "Ride", segment_locations: {}, distance_meters: 25000)
      strava_integration.update_sync_status
      expect(strava_gear.reload.total_distance_kilometers).to eq(25)
      # Un-enriched gear gets a fetch_gear request
      expect(StravaRequest.where(strava_integration_id: strava_integration.id, request_type: :fetch_gear).count).to eq(1)
      expect(strava_integration.reload.status).to eq("synced")
    end

    it "does not create duplicate detail requests when called twice" do
      FactoryBot.create(:strava_activity, strava_integration:, activity_type: "Ride", segment_locations: nil)
      strava_integration.update_sync_status
      expect(StravaRequest.where(strava_integration_id: strava_integration.id, request_type: :fetch_activity).count).to eq(1)
      strava_integration.update_sync_status
      expect(StravaRequest.where(strava_integration_id: strava_integration.id, request_type: :fetch_activity).count).to eq(1)
    end

    it "skips when activities_downloaded_count matches unless force_update" do
      FactoryBot.create(:strava_activity, strava_integration:, activity_type: "Ride", segment_locations: {})
      strava_integration.update(activities_downloaded_count: 1, status: :syncing)
      strava_integration.update_sync_status
      expect(strava_integration.reload.status).to eq("syncing")

      strava_integration.update_sync_status(force_update: true)
      expect(strava_integration.reload.status).to eq("synced")
    end
  end
end
