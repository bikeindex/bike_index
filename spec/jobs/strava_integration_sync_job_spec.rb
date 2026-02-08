require "rails_helper"

RSpec.describe StravaIntegrationSyncJob, type: :job do
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
        athlete_id: "12345678")
    end

    before { allow(Integrations::Strava).to receive(:sleep) }

    it "fetches athlete and syncs activities" do
      VCR.use_cassette("strava-get_athlete", match_requests_on: [:path]) do
        VCR.use_cassette("strava-get_athlete_stats", match_requests_on: [:path]) do
          VCR.use_cassette("strava-list_activities", match_requests_on: [:path]) do
            VCR.use_cassette("strava-get_activity_ride", match_requests_on: [:path]) do
              VCR.use_cassette("strava-get_activity_virtual_ride", match_requests_on: [:path]) do
                instance.perform(strava_integration.id)

                strava_integration.reload
                expect(strava_integration.athlete_activity_count).to eq(150)
                expect(strava_integration.status).to eq("synced")
                expect(strava_integration.strava_activities.count).to eq(3)
              end
            end
          end
        end
      end
    end

    it "does nothing when integration not found" do
      instance.perform(-1)
      # No error raised, no HTTP calls made
    end
  end
end
