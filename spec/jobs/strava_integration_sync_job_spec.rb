require "rails_helper"

RSpec.describe StravaIntegrationSyncJob, type: :job do
  let(:instance) { described_class.new }

  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
  end

  describe "perform" do
    let(:strava_integration) do
      FactoryBot.create(:strava_integration,
        access_token: ENV["STRAVA_TEST_ACCESS_TOKEN"],
        refresh_token: ENV["STRAVA_TEST_REFRESH_TOKEN"],
        token_expires_at: Time.current + 6.hours,
        athlete_id: ENV["STRAVA_TEST_USER_ID"])
    end

    it "fetches athlete, updates integration, and enqueues page sync" do
      VCR.use_cassette("strava-get_athlete") do
        VCR.use_cassette("strava-get_athlete_stats") do
          instance.perform(strava_integration.id)

          strava_integration.reload
          expect(strava_integration.athlete_id).to eq("2430215")
          expect(strava_integration.athlete_activity_count).to eq(1817)
          expect(strava_integration.status).to eq("syncing")
          expect(StravaActivityPageSyncJob.jobs.size).to eq(1)
        end
      end
    end

    it "does nothing when integration not found" do
      instance.perform(-1)
      expect(StravaActivityPageSyncJob.jobs.size).to eq(0)
    end
  end
end
