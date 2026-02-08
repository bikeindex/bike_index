require "rails_helper"

RSpec.describe StravaActivity, type: :model do
  describe "validations" do
    it "requires strava_id" do
      sa = FactoryBot.build(:strava_activity, strava_id: nil)
      expect(sa).not_to be_valid
      expect(sa.errors[:strava_id]).to be_present
    end

    it "requires unique strava_id per integration" do
      si = FactoryBot.create(:strava_integration)
      FactoryBot.create(:strava_activity, strava_integration: si, strava_id: "123")
      sa = FactoryBot.build(:strava_activity, strava_integration: si, strava_id: "123")
      expect(sa).not_to be_valid
      expect(sa.errors[:strava_id]).to be_present
    end

    it "allows same strava_id for different integrations" do
      si1 = FactoryBot.create(:strava_integration)
      si2 = FactoryBot.create(:strava_integration)
      FactoryBot.create(:strava_activity, strava_integration: si1, strava_id: "123")
      sa = FactoryBot.build(:strava_activity, strava_integration: si2, strava_id: "123")
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
    let(:si) { FactoryBot.create(:strava_integration) }

    it "cycling scope returns cycling activities" do
      ride = FactoryBot.create(:strava_activity, strava_integration: si, activity_type: "Ride")
      mtb = FactoryBot.create(:strava_activity, strava_integration: si, activity_type: "MountainBikeRide")
      gravel = FactoryBot.create(:strava_activity, strava_integration: si, activity_type: "GravelRide")
      virtual = FactoryBot.create(:strava_activity, strava_integration: si, activity_type: "VirtualRide")
      ebike = FactoryBot.create(:strava_activity, strava_integration: si, activity_type: "EBikeRide")
      emtb = FactoryBot.create(:strava_activity, strava_integration: si, activity_type: "EMountainBikeRide")
      run = FactoryBot.create(:strava_activity, :run, strava_integration: si)
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
    let(:si) { FactoryBot.create(:strava_integration) }
    let(:summary) do
      {"id" => 9876543, "name" => "Morning Ride", "distance" => 25000.0,
       "moving_time" => 3600, "total_elevation_gain" => 200.0,
       "sport_type" => "Ride", "type" => "Ride",
       "start_date" => "2025-06-15T08:00:00Z",
       "start_latlng" => [37.7749, -122.4194],
       "gear_id" => "b1234", "private" => false, "kudos_count" => 10}
    end

    it "creates a new activity from summary" do
      activity = StravaActivity.create_or_update_from_summary(si, summary)
      expect(activity).to be_persisted
      expect(activity.strava_id).to eq("9876543")
      expect(activity.title).to eq("Morning Ride")
      expect(activity.distance_meters).to eq(25000.0)
      expect(activity.moving_time_seconds).to eq(3600)
      expect(activity.total_elevation_gain_meters).to eq(200.0)
      expect(activity.sport_type).to eq("Ride")
      expect(activity.activity_type).to eq("Ride")
      expect(activity.kudos_count).to eq(10)
      expect(activity.start_latitude).to eq(37.7749)
    end

    it "updates an existing activity" do
      FactoryBot.create(:strava_activity, strava_integration: si, strava_id: "9876543", title: "Old Title")
      activity = StravaActivity.create_or_update_from_summary(si, summary)
      expect(activity.title).to eq("Morning Ride")
      expect(si.strava_activities.count).to eq(1)
    end
  end

  describe "update_from_detail" do
    let(:activity) { FactoryBot.create(:strava_activity) }
    let(:detail) do
      {"description" => "Great ride",
       "gear" => {"name" => "My Road Bike"},
       "muted" => false,
       "kudos_count" => 10,
       "segment_efforts" => [
         {"segment" => {"city" => "San Francisco", "state" => "California", "country" => "United States"}},
         {"segment" => {"city" => "Mill Valley", "state" => "California", "country" => "United States"}}
       ],
       "photos" => {"primary" => {"unique_id" => "photo_123", "urls" => {"600" => "https://example.com/photo.jpg"}}}}
    end

    it "updates the activity with detail fields" do
      activity.update_from_detail(detail)
      activity.reload
      expect(activity.description).to eq("Great ride")
      expect(activity.gear_name).to eq("My Road Bike")
      expect(activity.kudos_count).to eq(10)
      expect(activity.photos.first["id"]).to eq("photo_123")
      expect(activity.segment_locations).to eq(
        "cities" => ["San Francisco", "Mill Valley"],
        "states" => ["California"],
        "countries" => ["United States"]
      )
    end

    it "handles detail without segment efforts" do
      detail.delete("segment_efforts")
      activity.update_from_detail(detail)
      activity.reload
      expect(activity.segment_locations).to eq({})
    end

    it "handles detail without photos" do
      detail["photos"] = {"primary" => nil}
      activity.update_from_detail(detail)
      activity.reload
      expect(activity.photos).to eq([])
    end
  end
end
