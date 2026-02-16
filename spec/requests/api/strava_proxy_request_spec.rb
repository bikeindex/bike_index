# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Strava Proxy API", type: :request do
  let(:base_url) { "/api/strava_proxy" }

  let(:doorkeeper_app) { FactoryBot.create(:doorkeeper_app) }
  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:token) { Doorkeeper::AccessToken.create!(application_id: doorkeeper_app.id, resource_owner_id: user.id) }

  context "no token" do
    it "returns 401" do
      post base_url, params: {url: "athlete/activities", method: "GET"}
      expect(response.status).to eq 401
      expect(json_result[:error]).to eq "OAuth token required"
    end
  end

  context "token from wrong app" do
    it "returns 403" do
      stub_const("ENV", ENV.to_h.merge("STRAVA_DOORKEEPER_APP_ID" => "99999"))
      post base_url, params: {url: "athlete/activities", method: "GET", access_token: token.token}
      expect(response.status).to eq 403
      expect(json_result[:error]).to eq "Unauthorized application"
    end
  end

  context "STRAVA_DOORKEEPER_APP_ID not set" do
    it "returns 403" do
      stub_const("ENV", ENV.to_h.merge("STRAVA_DOORKEEPER_APP_ID" => nil))
      post base_url, params: {url: "athlete/activities", method: "GET", access_token: token.token}
      expect(response.status).to eq 403
    end
  end

  context "valid token and app" do
    before { stub_const("ENV", ENV.to_h.merge("STRAVA_DOORKEEPER_APP_ID" => doorkeeper_app.id.to_s)) }

    context "no strava integration" do
      it "returns 404" do
        post base_url, params: {url: "athlete/activities", method: "GET", access_token: token.token}
        expect(response.status).to eq 404
        expect(json_result[:error]).to eq "No Strava integration"
      end
    end

    context "with strava integration" do
      let!(:strava_integration) { FactoryBot.create(:strava_integration, user:) }
      let(:strava_response_body) { [{"id" => 123, "name" => "Morning Ride", "sport_type" => "Ride"}] }
      let(:strava_response) do
        instance_double(Faraday::Response, success?: true, status: 200, body: strava_response_body, headers: {})
      end

      before do
        allow(Integrations::StravaClient).to receive(:proxy_request).and_return(strava_response)
      end

      it "proxies the request and returns strava response" do
        expect {
          post base_url, params: {url: "athlete/activities", method: "GET", access_token: token.token}
        }.to change(StravaRequest, :count).by(1)
        expect(response.status).to eq 200
        expect(json_result).to eq strava_response_body
        strava_request = StravaRequest.last
        expect(strava_request.proxy?).to be_truthy
        expect(strava_request.success?).to be_truthy
        expect(strava_request.parameters).to eq("url" => "athlete/activities", "method" => "GET")
        expect(Integrations::StravaClient).to have_received(:proxy_request)
          .with(strava_integration, "athlete/activities", method: "GET")
      end

      context "strava returns an error" do
        let(:strava_response) do
          instance_double(Faraday::Response, success?: false, status: 429, body: {"message" => "Rate Limit Exceeded"}, headers: {})
        end

        it "returns strava error status" do
          post base_url, params: {url: "athlete/activities", method: "GET", access_token: token.token}
          expect(response.status).to eq 429
          expect(json_result[:error]).to eq "rate_limited"
          expect(StravaRequest.last.rate_limited?).to be_truthy
        end
      end

      context "activity detail response" do
        let(:strava_response_body) { {"id" => 456, "name" => "Evening Ride", "sport_type" => "Ride", "distance" => 25000.0} }
        let(:strava_response) do
          instance_double(Faraday::Response, success?: true, status: 200, body: strava_response_body, headers: {})
        end

        it "stores activity data" do
          expect {
            post base_url, params: {url: "activities/456", method: "GET", access_token: token.token}
          }.to change(StravaActivity, :count).by(1)
          activity = StravaActivity.last
          expect(activity.strava_id).to eq "456"
          expect(activity.title).to eq "Evening Ride"
        end
      end
    end
  end
end
