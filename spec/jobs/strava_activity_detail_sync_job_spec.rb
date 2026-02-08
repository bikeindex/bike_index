require "rails_helper"

RSpec.describe StravaActivityDetailSyncJob, type: :job do
  let(:instance) { described_class.new }

  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
  end

  describe "perform" do
    let(:strava_integration) do
      FactoryBot.create(:strava_integration,
        access_token: "strava_access_token_xyz",
        refresh_token: "strava_test_refresh_token_456",
        token_expires_at: Time.current + 6.hours,
        athlete_id: "12345678",
        status: :syncing)
    end
    let(:activity) do
      FactoryBot.create(:strava_activity,
        strava_integration:,
        strava_id: "9876543",
        activity_type: "Ride")
    end

    it "fetches detail and updates the activity" do
      VCR.use_cassette("strava-get_activity_ride", match_requests_on: [:path]) do
        instance.perform(activity.id)

        activity.reload
        expect(activity.description).to eq("Beautiful morning ride through Golden Gate Park. Perfect weather and great views.")
        expect(activity.location_city).to eq("San Francisco")
        expect(activity.location_state).to eq("California")
        expect(activity.gear_name).to eq("My Road Bike")
        expect(activity.photos).to be_present
        expect(activity.kudos_count).to eq(10)
        expect(activity.muted).to eq(false)
      end
    end

    it "marks integration as synced when mark_synced is true" do
      VCR.use_cassette("strava-get_activity_ride", match_requests_on: [:path]) do
        instance.perform(activity.id, true)

        expect(strava_integration.reload.status).to eq("synced")
      end
    end

    it "does not mark synced when mark_synced is false" do
      VCR.use_cassette("strava-get_activity_ride", match_requests_on: [:path]) do
        instance.perform(activity.id, false)

        expect(strava_integration.reload.status).to eq("syncing")
      end
    end

    it "does nothing when activity not found" do
      instance.perform(-1)
      # No error raised
    end
  end
end
