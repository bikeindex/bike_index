require "rails_helper"

RSpec.describe Integrations::Strava, type: :service do
  let(:strava_integration) do
    FactoryBot.create(:strava_integration,
      access_token: "strava_access_token_xyz",
      refresh_token: "strava_test_refresh_token_456",
      token_expires_at: Time.current + 6.hours,
      athlete_id: "12345678")
  end

  describe ".authorization_url" do
    it "builds the correct authorization URL" do
      url = described_class.authorization_url
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

  describe ".fetch_athlete" do
    it "returns athlete data" do
      VCR.use_cassette("strava-get_athlete", match_requests_on: [:path]) do
        result = described_class.fetch_athlete(strava_integration)
        expect(result["id"]).to eq(12345678)
        expect(result["bikes"]).to be_present
      end
    end
  end

  describe ".fetch_athlete_stats" do
    it "returns athlete stats" do
      VCR.use_cassette("strava-get_athlete_stats", match_requests_on: [:path]) do
        result = described_class.fetch_athlete_stats(strava_integration, "12345678")
        expect(result.dig("all_ride_totals", "count")).to eq(100)
      end
    end
  end

  describe ".list_activities" do
    it "returns activities for a page" do
      VCR.use_cassette("strava-list_activities", match_requests_on: [:path]) do
        result = described_class.list_activities(strava_integration, page: 1, per_page: 200)
        expect(result).to be_an(Array)
        expect(result.size).to eq(3)
        expect(result.first["name"]).to eq("Morning Ride")
      end
    end
  end

  describe ".fetch_activity" do
    it "returns activity detail" do
      VCR.use_cassette("strava-get_activity_ride", match_requests_on: [:path]) do
        result = described_class.fetch_activity(strava_integration, "9876543")
        expect(result["name"]).to eq("Morning Ride")
        expect(result["description"]).to be_present
        expect(result["location_city"]).to eq("San Francisco")
      end
    end
  end
end
