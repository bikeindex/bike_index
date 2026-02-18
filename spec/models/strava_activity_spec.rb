# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaActivity, type: :model do
  describe "validations" do
    it "requires strava_id" do
      sa = FactoryBot.build(:strava_activity, strava_id: nil)
      expect(sa).not_to be_valid
      expect(sa.errors[:strava_id]).to be_present
    end

    it "requires unique strava_id per integration" do
      strava_integration = FactoryBot.create(:strava_integration)
      FactoryBot.create(:strava_activity, strava_integration:, strava_id: "123")
      sa = FactoryBot.build(:strava_activity, strava_integration:, strava_id: "123")
      expect(sa).not_to be_valid
      expect(sa.errors[:strava_id]).to be_present
    end

    it "allows same strava_id for different integrations" do
      strava_integration1 = FactoryBot.create(:strava_integration)
      strava_integration2 = FactoryBot.create(:strava_integration)
      FactoryBot.create(:strava_activity, strava_integration: strava_integration1, strava_id: "123")
      sa = FactoryBot.build(:strava_activity, strava_integration: strava_integration2, strava_id: "123")
      expect(sa).to be_valid
    end
  end

  describe "associations" do
    it "belongs to strava_integration" do
      sa = FactoryBot.create(:strava_activity)
      expect(sa.strava_integration).to be_present
      expect(sa.strava_integration).to be_a(StravaIntegration)
    end
  end

  describe "scopes" do
    let(:strava_integration) { FactoryBot.create(:strava_integration) }

    it "cycling scope returns cycling activities" do
      ride = FactoryBot.create(:strava_activity, strava_integration:, activity_type: "Ride")
      mtb = FactoryBot.create(:strava_activity, strava_integration:, activity_type: "MountainBikeRide")
      gravel = FactoryBot.create(:strava_activity, strava_integration:, activity_type: "GravelRide")
      virtual = FactoryBot.create(:strava_activity, strava_integration:, activity_type: "VirtualRide")
      ebike = FactoryBot.create(:strava_activity, strava_integration:, activity_type: "EBikeRide")
      emtb = FactoryBot.create(:strava_activity, strava_integration:, activity_type: "EMountainBikeRide")
      run = FactoryBot.create(:strava_activity, :run, strava_integration:)
      expect(StravaActivity.cycling).to include(ride, mtb, gravel, virtual, ebike, emtb)
      expect(StravaActivity.cycling).not_to include(run)
    end
  end

  describe "cycling?" do
    it "returns true for all cycling sport types" do
      %w[Ride MountainBikeRide GravelRide EBikeRide EMountainBikeRide VirtualRide Handcycle Velomobile].each do |type|
        sa = FactoryBot.build(:strava_activity, activity_type: type)
        expect(sa.cycling?).to be_truthy
      end
    end

    it "returns false for non-cycling types" do
      %w[Run Swim Walk Hike TrailRun].each do |type|
        sa = FactoryBot.build(:strava_activity, activity_type: type)
        expect(sa.cycling?).to be_falsey
      end
    end
  end

  describe "distance_miles" do
    it "returns nil if distance_meters is nil" do
      sa = FactoryBot.build(:strava_activity, distance_meters: nil)
      expect(sa.distance_miles).to be_nil
    end

    it "converts meters to miles" do
      sa = FactoryBot.build(:strava_activity, distance_meters: 1609.344)
      expect(sa.distance_miles).to eq(1.0)
    end
  end

  describe "distance_km" do
    it "returns nil if distance_meters is nil" do
      sa = FactoryBot.build(:strava_activity, distance_meters: nil)
      expect(sa.distance_km).to be_nil
    end

    it "converts meters to kilometers" do
      sa = FactoryBot.build(:strava_activity, distance_meters: 5000.0)
      expect(sa.distance_km).to eq(5.0)
    end
  end

  describe "create_or_update_from_summary" do
    let(:strava_integration) { FactoryBot.create(:strava_integration) }
    let(:summary) do
      {"id" => 9876543, "name" => "Morning Ride", "distance" => 25000.0,
       "moving_time" => 3600, "total_elevation_gain" => 200.0,
       "sport_type" => "Ride", "type" => "Ride",
       "start_date" => "2025-06-15T08:00:00Z",
       "gear_id" => "b1234", "private" => false, "kudos_count" => 10,
       "average_speed" => 6.944, "suffer_score" => 42.0,
       "average_heartrate" => 145.0, "max_heartrate" => 180.0,
       "device_name" => "Garmin Edge 530", "commute" => false,
       "pr_count" => 3, "average_watts" => 200.0, "device_watts" => true}
    end

    it "creates a new activity from summary" do
      activity = StravaActivity.create_or_update_from_summary(strava_integration, summary)
      expect(activity).to be_persisted
      expect(activity).to match_hash_indifferently(
        strava_id: "9876543",
        title: "Morning Ride",
        distance_meters: 25000.0,
        moving_time_seconds: 3600,
        total_elevation_gain_meters: 200.0,
        sport_type: "Ride",
        activity_type: "Ride",
        kudos_count: 10,
        average_speed: 6.944,
        suffer_score: 42.0,
        start_date: "2025-06-15T08:00:00Z",
        gear_id: "b1234",
        private: false,
        strava_data: {
          average_heartrate: 145.0, max_heartrate: 180.0,
          device_name: "Garmin Edge 530", commute: false,
          average_speed: 6.944, pr_count: 3,
          average_watts: 200.0, device_watts: true
        }
      )
    end

    it "updates an existing activity" do
      FactoryBot.create(:strava_activity, strava_integration:, strava_id: "9876543", title: "Old Title")
      activity = StravaActivity.create_or_update_from_summary(strava_integration, summary)
      expect(activity.title).to eq("Morning Ride")
      expect(strava_integration.strava_activities.count).to eq(1)
    end
  end

  describe "update_from_detail" do
    let(:activity) { FactoryBot.create(:strava_activity) }
    let(:detail) do
      {"description" => "Great ride",
       "gear" => {"name" => "My Road Bike"},
       "kudos_count" => 10,
       "average_speed" => 5.5, "suffer_score" => 30.0,
       "average_heartrate" => 140.0, "max_heartrate" => 175.0,
       "device_name" => "Garmin Edge 530", "commute" => true,
       "muted" => false, "pr_count" => 2,
       "average_watts" => 180.0, "device_watts" => true,
       "segment_efforts" => [
         {"segment" => {"city" => "San Francisco", "state" => "California", "country" => "United States"}},
         {"segment" => {"city" => "Mill Valley", "state" => "California", "country" => "United States"}}
       ],
       "photos" => {"primary" => {"unique_id" => "photo_123", "urls" => {"600" => "https://example.com/photo.jpg"}}, "count" => 3}}
    end

    it "updates the activity with detail fields" do
      activity.update_from_detail(detail)
      activity.reload
      expect(activity).to match_hash_indifferently(
        description: "Great ride",
        kudos_count: 10,
        average_speed: 5.5,
        suffer_score: 30.0,
        photos: {photo_url: "https://example.com/photo.jpg", photo_count: 3},
        strava_data: {
          average_heartrate: 140.0, max_heartrate: 175.0,
          device_name: "Garmin Edge 530", commute: true,
          muted: false, average_speed: 5.5,
          pr_count: 2, average_watts: 180.0,
          device_watts: true
        },
        segment_locations: {
          cities: ["San Francisco", "Mill Valley"],
          states: ["California"],
          countries: ["United States"]
        }
      )
    end

    it "handles detail without segment efforts" do
      detail.delete("segment_efforts")
      activity.update_from_detail(detail)
      activity.reload
      expect(activity.segment_locations).to eq({})
    end

    it "handles detail without photos" do
      detail["photos"] = {"primary" => nil, "count" => 0}
      activity.update_from_detail(detail)
      activity.reload
      expect(activity).to match_hash_indifferently(photos: {photo_url: nil, photo_count: 0})
    end
  end
end
