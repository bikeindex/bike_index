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
      virtual = FactoryBot.create(:strava_activity, strava_integration: si, activity_type: "VirtualRide")
      ebike = FactoryBot.create(:strava_activity, strava_integration: si, activity_type: "EBikeRide")
      run = FactoryBot.create(:strava_activity, strava_integration: si, :run)
      expect(StravaActivity.cycling).to include(ride, virtual, ebike)
      expect(StravaActivity.cycling).not_to include(run)
    end
  end

  describe "cycling?" do
    it "returns true for cycling types" do
      %w[Ride VirtualRide EBikeRide Handcycle Velomobile].each do |type|
        sa = FactoryBot.build(:strava_activity, activity_type: type)
        expect(sa.cycling?).to be_truthy
      end
    end

    it "returns false for non-cycling types" do
      %w[Run Swim Walk Hike].each do |type|
        sa = FactoryBot.build(:strava_activity, activity_type: type)
        expect(sa.cycling?).to be_falsey
      end
    end
  end

  describe "distance_miles" do
    it "returns nil if distance is nil" do
      sa = FactoryBot.build(:strava_activity, distance: nil)
      expect(sa.distance_miles).to be_nil
    end

    it "converts meters to miles" do
      sa = FactoryBot.build(:strava_activity, distance: 1609.344)
      expect(sa.distance_miles).to eq(1.0)
    end
  end

  describe "distance_km" do
    it "returns nil if distance is nil" do
      sa = FactoryBot.build(:strava_activity, distance: nil)
      expect(sa.distance_km).to be_nil
    end

    it "converts meters to kilometers" do
      sa = FactoryBot.build(:strava_activity, distance: 5000.0)
      expect(sa.distance_km).to eq(5.0)
    end
  end
end
