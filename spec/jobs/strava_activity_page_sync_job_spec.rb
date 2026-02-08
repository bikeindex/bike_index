require "rails_helper"

RSpec.describe StravaActivityPageSyncJob, type: :job do
  let(:instance) { described_class.new }
  let(:strava_integration) do
    FactoryBot.create(:strava_integration,
      access_token: ENV["STRAVA_TEST_ACCESS_TOKEN"],
      refresh_token: ENV["STRAVA_TEST_REFRESH_TOKEN"],
      token_expires_at: Time.current + 6.hours,
      athlete_id: ENV["STRAVA_TEST_USER_ID"])
  end

  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
  end

  describe "perform" do
    it "saves activities from the page and enqueues detail jobs" do
      VCR.use_cassette("strava-list_activities") do
        expect {
          instance.perform(strava_integration.id, 1)
        }.to change(StravaActivity, :count).by(1)

        activity = strava_integration.strava_activities.first
        expect(activity.strava_id).to eq("17323701543")
        expect(activity.sport_type).to eq("EBikeRide")
        expect(activity.distance_meters).to eq(44936.4)
      end
    end

    it "updates activities_downloaded_count" do
      VCR.use_cassette("strava-list_activities") do
        instance.perform(strava_integration.id, 1)
        expect(strava_integration.reload.activities_downloaded_count).to eq(1)
      end
    end

    it "enqueues detail jobs for cycling activities and marks last as synced" do
      VCR.use_cassette("strava-list_activities") do
        instance.perform(strava_integration.id, 1)
        # EBikeRide is a cycling type
        expect(StravaActivityDetailSyncJob.jobs.size).to eq(1)
        expect(StravaActivityDetailSyncJob.jobs.last["args"].last).to eq(true)
      end
    end

    it "finishes sync when no cycling activities need details" do
      allow(Integrations::Strava).to receive(:list_activities).and_return(
        [{"id" => 9876544, "name" => "Evening Run", "distance" => 5000.0,
          "moving_time" => 1800, "total_elevation_gain" => 50.0,
          "sport_type" => "Run", "type" => "Run",
          "start_date" => "2025-06-14T18:00:00Z", "start_latlng" => nil,
          "private" => false, "kudos_count" => 3}]
      )
      instance.perform(strava_integration.id, 1)
      expect(strava_integration.reload.status).to eq("synced")
      expect(StravaActivityDetailSyncJob.jobs.size).to eq(0)
    end

    it "does nothing when integration not found" do
      instance.perform(-1, 1)
      expect(StravaActivity.count).to eq(0)
    end
  end
end
