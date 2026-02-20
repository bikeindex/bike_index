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
      stub_const("StravaJobs::ProxyRequester::STRAVA_DOORKEEPER_APP_ID", 99999)
      post base_url, params: {url: "athlete/activities", method: "GET", access_token: token.token}
      expect(response.status).to eq 403
      expect(json_result[:error]).to eq "Unauthorized application"
    end
  end

  context "valid token and app" do
    before { stub_const("StravaJobs::ProxyRequester::STRAVA_DOORKEEPER_APP_ID", doorkeeper_app.id) }

    context "no strava integration" do
      it "returns 404" do
        post base_url, params: {url: "athlete/activities", method: "GET", access_token: token.token}
        expect(response.status).to eq 404
        expect(json_result[:error]).to eq "No Strava integration"
      end
    end

    context "with strava integration not yet synced" do
      let!(:strava_integration) { FactoryBot.create(:strava_integration, user:, status: :syncing) }

      it "returns 422 with status" do
        post base_url, params: {url: "athlete/activities", method: "GET", access_token: token.token}
        expect(response.status).to eq 422
        expect(json_result[:error]).to eq "Strava integration not yet synced - status: syncing"
      end
    end

    context "with synced strava integration" do
      let!(:strava_integration) { FactoryBot.create(:strava_integration, :synced, :env_tokens, user:) }
      let(:target_attributes) do
        {
          strava_id: "17323701543",
          title: "Thanks for coming across the bay!",
          activity_type: "EBikeRide",
          sport_type: "EBikeRide",
          distance_meters: 44936.4,
          moving_time_seconds: 9468,
          total_elevation_gain_meters: 669.0,
          average_speed: 4.746,
          suffer_score: 27.0,
          kudos_count: 17,
          gear_id: "b14918050",
          private: false,
          timezone: "America/Los_Angeles",
          strava_data: {
            average_heartrate: 115.0, max_heartrate: 167.0,
            device_name: "Strava App", commute: false,
            average_speed: 4.746, pr_count: 0,
            average_watts: 129.0, device_watts: false
          }
        }.as_json
      end

      it "proxies the request and returns serialized response" do
        VCR.use_cassette("strava-list_activities") do
          expect {
            post base_url, params: {url: "athlete/activities?page=1&per_page=1", method: "GET", access_token: token.token}
          }.to change(StravaRequest, :count).by(1)
          expect(response.status).to eq 200
          expect(json_result).to be_a(Array)
          expect(json_result.first["title"]).to eq "Thanks for coming across the bay!"
          expect(json_result.first["strava_id"]).to eq "17323701543"
          strava_request = StravaRequest.last
          expect(strava_request.proxy?).to be_truthy
          expect(strava_request.success?).to be_truthy
          expect(strava_request.parameters).to eq("url" => "athlete/activities?page=1&per_page=1", "method" => "GET")

          strava_activity = strava_integration.strava_activities.find_by(strava_id: "17323701543")
          expect(strava_activity).to have_attributes target_attributes
          expect(strava_activity.start_date).to be_within(1).of Binxtils::TimeParser.parse("2026-02-07T23:39:36Z")
          expect(json_result).to eq [strava_activity.proxy_serialized.as_json]
        end
      end

      context "activity detail response" do
        let(:detail_target_attributes) do
          target_attributes.merge(
            description: "Hawk with Eric and Scott and cedar",
            photos: {
              photo_url: "https://dgtzuqphqg23d.cloudfront.net/AdftI2Cg62i6LQOs6W5N3iX67FhZCCr6-F0BdwkwUvw-768x576.jpg",
              photo_count: 2
            },
            segment_locations: {
              cities: ["San Francisco", "Mill Valley"],
              states: ["California"],
              countries: ["United States", "USA"]
            },
            strava_data: target_attributes["strava_data"].merge("enriched" => true, "muted" => false)
          ).as_json
        end

        it "creates from list then enriches from detail" do
          VCR.use_cassette("strava-list_activities") do
            post base_url, params: {url: "athlete/activities?page=1&per_page=1", method: "GET", access_token: token.token}
          end
          expect(response.status).to eq 200
          strava_activity = strava_integration.strava_activities.find_by(strava_id: "17323701543")
          expect(strava_activity).to have_attributes target_attributes
          expect(strava_activity.enriched?).to be_falsey

          VCR.use_cassette("strava-get_activity") do
            expect {
              post base_url, params: {url: "activities/17323701543", method: "GET", access_token: token.token}
            }.to_not change(StravaActivity, :count)
            expect(response.status).to eq 200
            expect(json_result["title"]).to eq "Thanks for coming across the bay!"
            expect(json_result["description"]).to eq "Hawk with Eric and Scott and cedar"
          end
          strava_activity.reload
          expect(strava_activity.enriched?).to be_truthy
          expect(strava_activity).to have_attributes detail_target_attributes
          expect(json_result).to eq strava_activity.proxy_serialized.as_json
        end
      end

      context "update activity via PUT" do
        let!(:strava_integration) { FactoryBot.create(:strava_integration, :synced, :env_tokens, user:, token_expires_at:) }
        let(:strava_id) { "17419209324" }
        let(:gear_id) { "b11099574" }
        let!(:strava_activity) { FactoryBot.create(:strava_activity, strava_integration:, strava_id:) }
        let(:token_expires_at) { Time.current - 1.hour }
        let(:expected_parameters) { {body: {gear_id: "b11099574"}, method: "PUT", url: "activities/17419209324"} }

        it "returns insufficient_token_privileges response" do
          expect(strava_integration.reload.token_expired?).to be_truthy
          og_token = strava_integration.access_token

          VCR.use_cassette("strava-proxy_update_activity-insufficient") do
            expect {
              post base_url, params: {
                url: "activities/#{strava_id}", method: "PUT", access_token: token.token, body: {gear_id:}
              }
            }.to change(StravaRequest, :count).by(1)
          end

          expect(response.status).to eq 404
          expect(json_result["message"]).to eq "Resource Not Found"
          expect(json_result["errors"]).to be_present

          strava_request = StravaRequest.last
          expect(strava_request.proxy?).to be_truthy
          expect(strava_request.response_status).to eq "insufficient_token_privileges"
          expect(strava_request.parameters).to eq expected_parameters.as_json

          expect(strava_integration.reload.token_expired?).to be_falsey
          expect(strava_integration.access_token).to_not eq og_token
        end

        context "with valid token permissions" do
          let(:token_expires_at) { Time.current + 1.hour }
          let(:target_attributes) do
            {
              strava_id:,
              title: "Extra 10: HIIT Ride with Cody Rigsby",
              description: "Total Output: 94 kJ\n" + "Leaderboard Rank: 6,555 / 32,313",
              distance_meters: 5079.8,
              moving_time_seconds: 600,
              total_elevation_gain_meters: 0.0,
              sport_type: "Ride",
              private: false,
              kudos_count: 2,
              gear_id:,
              photos: {photo_url: nil, photo_count: 0},
              segment_locations: {},
              activity_type: "Ride",
              timezone: "America/Chicago",
              average_speed: 8.466,
              suffer_score: 2.0,
              strava_data: {
                commute: false,
                enriched: true,
                muted: true,
                pr_count: 0,
                device_name: "Peloton Bike",
                device_watts: true,
                average_speed: 8.466,
                average_watts: 156.0,
                max_heartrate: 149.0,
                average_heartrate: 136.2
              }
            }.as_json
          end
          it "updates the activity" do
            expect(strava_integration.reload.token_expired?).to be_falsey
            og_token = strava_integration.access_token
            expect(strava_activity.reload.enriched?).to be_falsey

            VCR.use_cassette("strava-proxy_update_activity") do
              expect {
                post base_url, params: {
                  url: "activities/#{strava_id}", method: "PUT", access_token: token.token, body: {gear_id:}
                }
              }.to change(StravaRequest, :count).by(1)
            end

            expect(response.status).to eq 200
            expect(strava_integration.access_token).to eq og_token

            strava_request = StravaRequest.last
            expect(strava_request.proxy?).to be_truthy
            expect(strava_request.success?).to be_truthy
            expect(strava_request.parameters).to eq expected_parameters.as_json

            expect(strava_activity.reload.enriched?).to be_truthy
            expect(strava_activity).to have_attributes target_attributes
            expect(strava_activity.start_date).to be_within(1).of Time.at(1771267927)
            expect(json_result).to eq strava_activity.proxy_serialized.as_json
          end
        end
      end

      context "strava returns rate limit error" do
        it "returns strava error status" do
          VCR.use_cassette("strava-proxy_rate_limited") do
            expect do
              post base_url, params: {url: "athlete/activities", method: "GET", access_token: token.token}
            end.to change(StravaRequest, :count).by 1
            expect(response.status).to eq 429
            expect(json_result["message"]).to eq "Rate Limit Exceeded"
            expect(json_result["errors"]).to be_present
            expect(StravaRequest.last.rate_limited?).to be_truthy
          end
        end
      end

      context "strava returns not found" do
        let(:expected_response_body) { {message: "Record Not Found", errors: [{resource: "resource", field: "path", code: "invalid"}]} }
        it "returns strava error status" do
          VCR.use_cassette("strava-proxy_not_found") do
            expect do
              post base_url, params: {url: "athlete/activities/3333333", method: "GET", access_token: token.token}
            end.to change(StravaRequest, :count).by 1
            expect(response.status).to eq 404
            expect(json_result).to eq expected_response_body.as_json

            strava_request = StravaRequest.last
            expect(strava_request.proxy?).to be_truthy
            expect(strava_request.success?).to be_falsey
            expect(strava_request.response_status).to eq "error"
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
            expect(json_result["message"]).to eq "Internal Server Error"
            expect(StravaRequest.last.error?).to be_truthy
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
