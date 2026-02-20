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

  describe "create_or_update_from_strava_response" do
    let(:strava_integration) { FactoryBot.create(:strava_integration) }
    let(:summary) do
      {id: 9876543, name: "Morning Ride", distance: 25000.0,
       moving_time: 3600, total_elevation_gain: 200.0,
       sport_type: "Ride", type: "Ride",
       start_date: "2025-06-15T08:00:00Z",
       timezone: "(GMT-07:00) America/Denver",
       gear_id: "b1234", private: false, kudos_count: 10,
       average_speed: 6.944, suffer_score: 42.0,
       average_heartrate: 145.0, max_heartrate: 180.0,
       device_name: "Garmin Edge 530", commute: false,
       pr_count: 3, average_watts: 200.0, device_watts: true}.as_json
    end

    it "creates a new activity from summary" do
      strava_activity = StravaActivity.create_or_update_from_strava_response(strava_integration, summary)
      expect(strava_activity).to be_persisted
      expect(strava_activity).to have_attributes({
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
        timezone: "America/Denver",
        gear_id: "b1234",
        private: false,
        strava_data: {
          average_heartrate: 145.0, max_heartrate: 180.0,
          device_name: "Garmin Edge 530", commute: false,
          average_speed: 6.944, pr_count: 3,
          average_watts: 200.0, device_watts: true
        }.as_json
      })
      expect(strava_activity.start_date).to be_within(1).of Time.at(1749974400)
    end

    it "updates an existing activity" do
      FactoryBot.create(:strava_activity, strava_integration:, strava_id: "9876543", title: "Old Title")
      strava_activity = StravaActivity.create_or_update_from_strava_response(strava_integration, summary)
      expect(strava_activity.title).to eq("Morning Ride")
      expect(strava_integration.strava_activities.count).to eq(1)
    end
  end

  describe "proxy_serialized" do
    let(:target) do
      {
        activity_type: "Ride",
        average_speed: 6.944,
        description: "Great ride",
        distance_meters: 25000.0,
        kudos_count: 10,
        moving_time_seconds: 3600,
        photos: {photo_url: "https://example.com/photo.jpg", photo_count: 3},
        private: false,
        segment_locations: {cities: ["Denver"], states: ["Colorado"], countries: ["United States"]},
        sport_type: "Ride",
        suffer_score: 42.0,
        timezone: "America/Denver",
        title: "Morning Ride",
        total_elevation_gain_meters: 200.0,
        gear_id: "b1234",
        strava_id: "123",
        average_heartrate: 145.0,
        max_heartrate: 180.0,
        device_name: "Garmin Edge 530",
        commute: false,
        pr_count: 3,
        average_watts: 200.0,
        device_watts: true
      }
    end
    it "returns PROXY_ATTRS merged with strava_data" do
      strava_activity = FactoryBot.build(:strava_activity,
        strava_id: "123",
        title: "Morning Ride",
        activity_type: "Ride",
        sport_type: "Ride",
        description: "Great ride",
        distance_meters: 25000.0,
        moving_time_seconds: 3600,
        total_elevation_gain_meters: 200.0,
        average_speed: 6.944,
        suffer_score: 42.0,
        kudos_count: 10,
        gear_id: "b1234",
        private: false,
        timezone: "America/Denver",
        start_date: Time.current,
        photos: {photo_url: "https://example.com/photo.jpg", photo_count: 3},
        segment_locations: {cities: ["Denver"], states: ["Colorado"], countries: ["United States"]},
        strava_data: {average_heartrate: 145.0, max_heartrate: 180.0, device_name: "Garmin Edge 530",
                      commute: false, average_speed: 6.944, pr_count: 3, average_watts: 200.0, device_watts: true})

      expect(strava_activity.proxy_serialized.except("start_date", "start_date_in_zone")).to eq target.as_json
      expect(strava_activity.proxy_serialized["start_date"]).to be_within(1).of Time.current
      expect(strava_activity.proxy_serialized["start_date_in_zone"].time_zone.name).to eq strava_activity.timezone
    end
  end

  describe "update_from_strava!" do
    let(:strava_integration) { FactoryBot.create(:strava_integration, :synced, :env_tokens) }
    let(:strava_activity) { StravaActivity.create(strava_integration:, strava_id: "17419209324") }
    let(:target_attributes) do
      {
        gear_id: "b11099574",
        title: "Extra 10: HIIT Ride with Cody Rigsby",
        description: "Total Output: 94 kJ\n" + "Leaderboard Rank: 6,555 / 32,313",
        photos: {
          photo_url: "https://dgtzuqphqg23d.cloudfront.net/lDHfSHn0XR7kn5dltGzfOIgJlAdwjgqM4_6HbGt95l4-768x432.jpg",
          photo_count: 1
        },
        strava_data: {
          commute: false,
          enriched: true,
          pr_count: 0,
          device_name: "Peloton Bike",
          device_watts: true,
          average_speed: 8.466,
          average_watts: 156.0,
          max_heartrate: 149.0,
          average_heartrate: 136.2,
          muted: true
        }
      }
    end
    it "updates from strava" do
      expect(strava_activity).to be_valid
      VCR.use_cassette("strava-update_from_strava") do
        strava_activity.update_from_strava!
      end
      expect(strava_activity.reload).to have_attributes target_attributes.as_json
    end
  end
end
