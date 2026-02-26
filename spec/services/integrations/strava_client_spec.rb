# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::StravaClient, type: :service do
  let(:strava_integration) do
    FactoryBot.create(:strava_integration,
      token_expires_at: Time.current + 6.hours,
      status:,
      athlete_id: ENV["STRAVA_TEST_USER_ID"])
  end
  let(:status) { :pending }

  describe ".authorization_url" do
    it "builds the correct authorization URL with state" do
      url = described_class.authorization_url(state: "test_state")
      expect(url).to include("https://www.strava.com/oauth/authorize")
      expect(url).to include("response_type=code")
      expect(url).to include("scope=read%2Cactivity%3Aread_all")
      expect(url).to include("redirect_uri=")
      expect(url).to include("state=test_state")
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
        response = described_class.fetch_athlete(strava_integration)
        expect(response).to be_a(Faraday::Response)
        expect(response.body["id"]).to eq(2430215)
        expect(response.body["username"]).to eq("sethherr")
      end
    end
  end

  describe ".fetch_athlete_stats" do
    it "returns athlete stats" do
      VCR.use_cassette("strava-get_athlete_stats") do
        response = described_class.fetch_athlete_stats(strava_integration)
        expect(response.body["all_ride_totals"]["count"]).to eq(1655)
        expect(response.body["all_run_totals"]["count"]).to eq(162)
      end
    end
  end

  describe ".list_activities" do
    it "returns activities for a page" do
      VCR.use_cassette("strava-list_activities") do
        response = described_class.list_activities(strava_integration, per_page: 1)
        expect(response.body).to be_an(Array)
        expect(response.body.size).to eq(1)
        expect(response.body.first["sport_type"]).to eq("EBikeRide")
      end
    end
  end

  describe ".fetch_activity" do
    it "returns activity detail with description, gear, and photos" do
      VCR.use_cassette("strava-get_activity") do
        response = described_class.fetch_activity(strava_integration, "17323701543")
        expect(response.body["id"]).to eq(17323701543)
        expect(response.body["description"]).to be_present
        expect(response.body["gear"]["name"]).to eq("Yuba longtail")
        expect(response.body["photos"]["primary"]).to be_present
      end
    end

    context "with a erroring token" do
      let(:status) { "synced" }
      let(:expires_at) { Time.current + 6.hours }
      it "updates strava_integration to be errored" do
        VCR.use_cassette("strava-get_activity-401") do
          expect(strava_integration.reload.status).to eq "synced"
          expect(strava_integration.token_expires_at).to be_within(5).of expires_at
          response = described_class.fetch_activity(strava_integration, "17323701543")
          expect(strava_integration.reload.status).to eq "error"
          expect(strava_integration.token_expires_at).to be_within(5).of expires_at
          expect(response.body["errors"]).to eq([{code: "invalid", field: "", resource: "Application"}].as_json)
        end
      end
    end
  end

  describe ".fetch_gear" do
    it "returns gear detail with resource_state 3" do
      VCR.use_cassette("strava-get_gear") do
        response = described_class.fetch_gear(strava_integration, "b12345")
        expect(response.body["id"]).to eq("b12345")
        expect(response.body["resource_state"]).to eq(3)
        expect(response.body["name"]).to eq("Yuba longtail")
        expect(response.body["frame_type"]).to be_present
      end
    end
  end

  describe ".proxy_request" do
    it "retries with refreshed token on 401 from Strava" do
      VCR.use_cassette("strava-proxy_request_401_retry") do
        response = described_class.proxy_request(strava_integration, "athlete")
        expect(response.status).to eq(200)
        expect(response.body["id"]).to eq(2430215)
        strava_integration.reload
        expect(strava_integration.token_expires_at).to be > Time.current
      end
    end
  end

  describe ".create_webhook_subscription" do
    before { stub_const("Integrations::StravaClient::STRAVA_WEBHOOK_TOKEN", "test_verify_token") }

    it "creates a webhook subscription" do
      VCR.use_cassette("strava-create_webhook_subscription") do
        response = described_class.create_webhook_subscription
        expect(response.status).to eq(201)
        expect(response.body["id"]).to eq(123456)
        expect(response.body["callback_url"]).to include("/webhooks/strava")
      end
    end
  end

  describe ".view_webhook_subscriptions" do
    it "returns existing subscriptions" do
      VCR.use_cassette("strava-view_webhook_subscriptions") do
        response = described_class.view_webhook_subscriptions
        expect(response.status).to eq(200)
        expect(response.body).to be_an(Array)
        expect(response.body.first["id"]).to eq(123456)
      end
    end
  end

  describe ".delete_webhook_subscription" do
    it "deletes a subscription by id" do
      VCR.use_cassette("strava-delete_webhook_subscription") do
        response = described_class.delete_webhook_subscription(123456)
        expect(response.status).to eq(204)
      end
    end
  end
end
