require "rails_helper"

RSpec.describe Integrations::Strava, type: :service do
  let(:strava_integration) do
    FactoryBot.create(:strava_integration,
      token_expires_at: Time.current + 6.hours,
      athlete_id: "2430215")
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
      VCR.use_cassette("strava-exchange_token") do
        result = described_class.exchange_token("test_auth_code")
        expect(result).to be_present
        expect(result["access_token"]).to be_present
        expect(result["refresh_token"]).to be_present
        expect(result["athlete"]["id"]).to eq(2430215)
      end
    end

    it "returns nil for invalid code" do
      VCR.use_cassette("strava-exchange_token_failure") do
        result = described_class.exchange_token("bad_code")
        expect(result).to be_nil
      end
    end
  end

  describe ".fetch_athlete" do
    it "returns athlete data" do
      VCR.use_cassette("strava-get_athlete") do
        result = described_class.fetch_athlete(strava_integration)
        expect(result["id"]).to eq(2430215)
        expect(result["username"]).to eq("sethherr")
      end
    end
  end

  describe ".fetch_athlete_stats" do
    it "returns athlete stats" do
      VCR.use_cassette("strava-get_athlete_stats") do
        result = described_class.fetch_athlete_stats(strava_integration, "2430215")
        expect(result["all_ride_totals"]["count"]).to eq(1655)
        expect(result["all_run_totals"]["count"]).to eq(162)
      end
    end
  end

  describe ".list_activities" do
    it "returns activities for a page" do
      VCR.use_cassette("strava-list_activities") do
        result = described_class.list_activities(strava_integration, page: 1, per_page: 1)
        expect(result).to be_an(Array)
        expect(result.size).to eq(1)
        expect(result.first["sport_type"]).to eq("EBikeRide")
      end
    end
  end

  describe ".fetch_activity" do
    it "returns activity detail with description, gear, and photos" do
      VCR.use_cassette("strava-get_activity") do
        result = described_class.fetch_activity(strava_integration, "17323701543")
        expect(result["id"]).to eq(17323701543)
        expect(result["description"]).to be_present
        expect(result["gear"]["name"]).to eq("Yuba longtail")
        expect(result["photos"]["primary"]).to be_present
      end
    end
  end
end
