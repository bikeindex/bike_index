require "rails_helper"

RSpec.describe Integrations::StravaConnection, type: :service do
  let(:strava_integration) do
    FactoryBot.create(:strava_integration,
      access_token: "strava_access_token_xyz",
      refresh_token: "strava_test_refresh_token_456",
      token_expires_at: Time.current + 6.hours,
      athlete_id: "12345678")
  end

  before { allow(described_class).to receive(:sleep) }

  describe ".authorization_url" do
    it "builds the correct authorization URL" do
      url = described_class.authorization_url("https://bikeindex.org/strava/callback")
      expect(url).to include("https://www.strava.com/oauth/authorize")
      expect(url).to include("response_type=code")
      expect(url).to include("scope=read%2Cactivity%3Aread_all")
      expect(url).to include("redirect_uri=")
    end
  end

  describe ".exchange_token" do
    it "exchanges authorization code for tokens" do
      VCR.use_cassette("strava-exchange_token", match_requests_on: [:path]) do
        result = described_class.exchange_token("test_auth_code")
        expect(result).to be_present
        expect(result["access_token"]).to eq("strava_access_token_xyz")
        expect(result["refresh_token"]).to eq("strava_refresh_token_abc")
        expect(result["athlete"]["id"]).to eq(12345678)
      end
    end
  end

  describe ".fetch_athlete_and_update" do
    it "fetches athlete profile and updates integration" do
      VCR.use_cassette("strava-get_athlete", match_requests_on: [:path]) do
        VCR.use_cassette("strava-get_athlete_stats", match_requests_on: [:path]) do
          described_class.fetch_athlete_and_update(strava_integration)

          strava_integration.reload
          expect(strava_integration.athlete_id).to eq("12345678")
          expect(strava_integration.athlete_activity_count).to eq(150)
          expect(strava_integration.athlete_gear).to be_present
          expect(strava_integration.athlete_gear.find { |g| g["name"] == "My Road Bike" }).to be_present
          expect(strava_integration.athlete_gear.find { |g| g["name"] == "My Mountain Bike" }).to be_present
        end
      end
    end
  end

  describe ".sync_all_activities" do
    it "downloads activities and saves them" do
      VCR.use_cassette("strava-list_activities", match_requests_on: [:path]) do
        VCR.use_cassette("strava-get_activity_ride", match_requests_on: [:path]) do
          VCR.use_cassette("strava-get_activity_virtual_ride", match_requests_on: [:path]) do
            expect {
              described_class.sync_all_activities(strava_integration)
            }.to change(StravaActivity, :count).by(3)
          end
        end
      end
    end

    it "fetches detailed info for cycling activities" do
      VCR.use_cassette("strava-list_activities", match_requests_on: [:path]) do
        VCR.use_cassette("strava-get_activity_ride", match_requests_on: [:path]) do
          VCR.use_cassette("strava-get_activity_virtual_ride", match_requests_on: [:path]) do
            described_class.sync_all_activities(strava_integration)

            ride = strava_integration.strava_activities.find_by(strava_id: "9876543")
            expect(ride.title).to eq("Morning Ride")
            expect(ride.description).to eq("Beautiful morning ride through Golden Gate Park. Perfect weather and great views.")
            expect(ride.location_city).to eq("San Francisco")
            expect(ride.location_state).to eq("California")
            expect(ride.gear_name).to eq("My Road Bike")
            expect(ride.photos).to be_present
          end
        end
      end
    end

    it "does not fetch details for non-cycling activities" do
      VCR.use_cassette("strava-list_activities", match_requests_on: [:path]) do
        VCR.use_cassette("strava-get_activity_ride", match_requests_on: [:path]) do
          VCR.use_cassette("strava-get_activity_virtual_ride", match_requests_on: [:path]) do
            described_class.sync_all_activities(strava_integration)

            run = strava_integration.strava_activities.find_by(strava_id: "9876544")
            expect(run.title).to eq("Evening Run")
            expect(run.activity_type).to eq("Run")
            expect(run.description).to be_nil
            expect(run.location_city).to be_nil
          end
        end
      end
    end

    it "updates status to synced on completion" do
      VCR.use_cassette("strava-list_activities", match_requests_on: [:path]) do
        VCR.use_cassette("strava-get_activity_ride", match_requests_on: [:path]) do
          VCR.use_cassette("strava-get_activity_virtual_ride", match_requests_on: [:path]) do
            described_class.sync_all_activities(strava_integration)
            expect(strava_integration.reload.status).to eq("synced")
          end
        end
      end
    end

    it "tracks download progress" do
      VCR.use_cassette("strava-list_activities", match_requests_on: [:path]) do
        VCR.use_cassette("strava-get_activity_ride", match_requests_on: [:path]) do
          VCR.use_cassette("strava-get_activity_virtual_ride", match_requests_on: [:path]) do
            described_class.sync_all_activities(strava_integration)
            expect(strava_integration.reload.activities_downloaded_count).to eq(3)
          end
        end
      end
    end
  end
end
