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
      stub_const("API::StravaProxyController::STRAVA_DOORKEEPER_APP_ID", "99999")
      post base_url, params: {url: "athlete/activities", method: "GET", access_token: token.token}
      expect(response.status).to eq 403
      expect(json_result[:error]).to eq "Unauthorized application"
    end
  end

  context "STRAVA_DOORKEEPER_APP_ID not set" do
    it "returns 403" do
      stub_const("API::StravaProxyController::STRAVA_DOORKEEPER_APP_ID", nil)
      post base_url, params: {url: "athlete/activities", method: "GET", access_token: token.token}
      expect(response.status).to eq 403
    end
  end

  context "valid token and app" do
    before { stub_const("API::StravaProxyController::STRAVA_DOORKEEPER_APP_ID", doorkeeper_app.id.to_s) }

    context "no strava integration" do
      it "returns 404" do
        post base_url, params: {url: "athlete/activities", method: "GET", access_token: token.token}
        expect(response.status).to eq 404
        expect(json_result[:error]).to eq "No Strava integration"
      end
    end

    context "with strava integration" do
      let!(:strava_integration) { FactoryBot.create(:strava_integration, user:) }

      it "proxies the request and returns strava response" do
        VCR.use_cassette("strava-proxy_activities") do
          expect {
            post base_url, params: {url: "athlete/activities", method: "GET", access_token: token.token}
          }.to change(StravaRequest, :count).by(1)
          expect(response.status).to eq 200
          expect(json_result).to eq [{"id" => 123, "name" => "Morning Ride", "sport_type" => "Ride", "distance" => 25000.0, "moving_time" => 3600, "type" => "Ride"}]
          strava_request = StravaRequest.last
          expect(strava_request.proxy?).to be_truthy
          expect(strava_request.success?).to be_truthy
          expect(strava_request.parameters).to eq("url" => "athlete/activities", "method" => "GET")
        end
      end

      context "strava returns rate limit error" do
        it "returns strava error status" do
          VCR.use_cassette("strava-proxy_rate_limited") do
            expect do
              post base_url, params: {url: "athlete/activities", method: "GET", access_token: token.token}
            end.to change(StravaRequest, :count).by 1
            expect(response.status).to eq 429
            expect(json_result[:error]).to eq "rate_limited"
            expect(StravaRequest.last.rate_limited?).to be_truthy
          end
        end
      end

      context "strava returns server error" do
        it "returns strava error status without raising" do
          VCR.use_cassette("strava-proxy_server_error") do
            expect do
              post base_url, params: {url: "athlete/activities", method: "GET", access_token: token.token}
            end.to change(StravaRequest, :count).by 1
            expect(response.status).to eq 500
            expect(json_result[:error]).to eq "error"
            expect(StravaRequest.last.error?).to be_truthy
          end
        end
      end

      context "activity detail response" do
        let(:target_keys) do
          []
        end
        it "stores activity data" do
          VCR.use_cassette("strava-proxy_activity_detail") do
            expect {
              post base_url, params: {url: "activities/456", method: "GET", access_token: token.token}
              expect(json_result.keys.sort).to eq target_keys
              expect(json_result["ssss"]).to eq "{C{CC"
            }.to change(StravaActivity, :count).by(1)
              .and change(StravaRequest, :count).by(1)
            activity = StravaActivity.last
            expect(activity.strava_id).to eq "456"
            expect(activity.title).to eq "Evening Ride"
          end
        end
      end

      context "invalid proxy path" do
        it "rejects absolute URLs" do
          expect do
            post base_url, params: {url: "https://evil.com/steal", method: "GET", access_token: token.token}
          end.to_not change(StravaRequest, :count)
          expect(response.status).to eq 400
        end

        it "rejects protocol-relative URLs" do
          expect do
            post base_url, params: {url: "//evil.com/steal", method: "GET", access_token: token.token}
          end.to_not change(StravaRequest, :count)
          expect(response.status).to eq 400
        end

        it "rejects path traversal" do
          expect do
            post base_url, params: {url: "../../oauth/token", method: "GET", access_token: token.token}
          end.to_not change(StravaRequest, :count)
          expect(response.status).to eq 400
        end
      end
    end
  end
end




