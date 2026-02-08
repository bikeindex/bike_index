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

    it "validates status inclusion" do
      si = FactoryBot.build(:strava_integration, status: "invalid")
      expect(si).not_to be_valid
      expect(si.errors[:status]).to be_present
    end

    it "allows valid statuses" do
      %w[pending syncing synced error].each do |status|
        si = FactoryBot.build(:strava_integration, status: status)
        expect(si.errors[:status]).to be_blank
      end
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
      si.status = "syncing"
      expect(si.syncing?).to be_truthy
      si.status = "synced"
      expect(si.syncing?).to be_falsey
    end

    it "synced?" do
      si.status = "synced"
      expect(si.synced?).to be_truthy
      si.status = "syncing"
      expect(si.synced?).to be_falsey
    end

    it "error?" do
      si.status = "error"
      expect(si.error?).to be_truthy
      si.status = "synced"
      expect(si.error?).to be_falsey
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
end
