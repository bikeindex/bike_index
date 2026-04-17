# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Strava Proxy API", type: :request do
  let(:base_url) { "/api/strava_proxy" }

  let(:doorkeeper_app) { FactoryBot.create(:doorkeeper_app) }
  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:doorkeeper_token) { Doorkeeper::AccessToken.create!(application_id: doorkeeper_app.id, resource_owner_id: user.id) }

  context "no token" do
    it "returns 401" do
      post base_url, params: {url: "athlete/activities", method: "GET"}
      expect(response.status).to eq 401
      expect(json_result[:error]).to eq "OAuth token required"
      expect(StravaRequest.count).to eq 0
    end
  end

  context "token from wrong app" do
    it "returns 403" do
      ENV["STRAVA_DOORKEEPER_APP_ID"] = "99999"
      post base_url, params: {url: "athlete/activities", method: "GET", access_token: doorkeeper_token.token}
      expect(response.status).to eq 403
      expect(json_result[:error]).to eq "Unauthorized application"
      expect(StravaRequest.count).to eq 0
    end
  end

  context "valid token and app" do
    before { ENV["STRAVA_DOORKEEPER_APP_ID"] = doorkeeper_app.id.to_s }

    context "no strava integration" do
      it "returns 404" do
        post base_url, params: {url: "athlete/activities", method: "GET", access_token: doorkeeper_token.token}
        expect(response.status).to eq 404
        expect(json_result[:error]).to eq "No Strava integration"
        expect(StravaRequest.count).to eq 0
      end
    end

    context "with strava integration in error status" do
      let!(:strava_integration) { FactoryBot.create(:strava_integration, user:, status: :error) }

      it "returns 401 with reauth message and does not create a proxy request" do
        expect {
          post base_url, params: {url: "athlete/activities", method: "GET", access_token: doorkeeper_token.token}
        }.to_not change(StravaRequest, :count)
        expect(response.status).to eq 401
        expect(json_result[:error]).to eq "Strava authorization failed. Please re-authenticate with Strava."
        expect(StravaRequest.count).to eq 0
      end
    end

    context "with strava integration not yet synced" do
      let!(:strava_integration) { FactoryBot.create(:strava_integration, :syncing, user:) }

      it "returns sync_status instead of proxying" do
        post base_url, params: {sync_status: true, access_token: doorkeeper_token.token}
        expect(response.status).to eq 200
        expect(json_result[:sync_status][:status]).to eq "syncing"
        expect(json_result[:sync_status][:activities_downloaded_count]).to eq 50
        expect(json_result[:sync_status][:athlete_activity_count]).to eq 150
        expect(json_result[:sync_status][:progress_percent]).to eq 33
        expect(StravaRequest.count).to eq 0
      end
    end

    context "with synced strava integration requesting sync_status" do
      let!(:strava_integration) { FactoryBot.create(:strava_integration, :synced, :env_tokens, user:) }

      it "returns synced status without proxying to Strava" do
        post base_url, params: {sync_status: true, access_token: doorkeeper_token.token}
        expect(response.status).to eq 200
        expect(json_result[:sync_status][:status]).to eq "synced"
        expect(StravaRequest.count).to eq 0
      end
    end

    context "with synced strava integration" do
      before { FactoryBot.create(:state_california) }
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
          enriched_at: nil,
          timezone: "America/Los_Angeles",
          strava_data: {
            average_heartrate: 115.0, max_heartrate: 167.0,
            device_name: "Strava App", commute: false, trainer: false,
            average_speed: 4.746, pr_count: 0,
            average_watts: 129.0, device_watts: false
          }
        }
      end

      context "list_activities request" do
        it "proxies the request and returns serialized response" do
          strava_activity = StravaActivity.new(strava_integration_id: strava_integration.id)
          strava_activity.update!(target_attributes)

          expect {
            post base_url, params: {url: "athlete/activities?page=1", method: "GET", access_token: doorkeeper_token.token}
          }.to change(StravaRequest, :count).by(1)
          expect(response.status).to eq 200
          expect(json_result).to be_a(Array)
          expect(json_result.first["title"]).to eq "Thanks for coming across the bay!"
          expect(json_result).to eq [strava_activity.proxy_serialized.as_json]

          strava_request = StravaRequest.last
          expect(strava_request).to have_attributes(proxy_request: true, request_type: "list_activities",
            response_status: "binx_response", parameters: {"url" => "athlete/activities?page=1"})
          expect(strava_request.requested_at).to be_within(1).of Time.current
        end

        context "page beyond available activities" do
          it "returns empty array" do
            expect {
              post base_url, params: {url: "athlete/activities?page=999", method: "GET", access_token: doorkeeper_token.token}
            }.to change(StravaRequest, :count).by(1)
            expect(response.status).to eq 200
            expect(json_result).to eq []
          end
        end
      end

      context "get_athlete request" do
        it "returns proxy_serialized without creating a strava_request" do
          expect {
            post base_url, params: {url: "athlete/2430215", method: " get ", access_token: doorkeeper_token.token}
          }.to change(StravaRequest, :count).by(1)
          expect(response.status).to eq 200
          expect(json_result).to eq strava_integration.proxy_serialized.as_json

          strava_request = StravaRequest.last
          expect(strava_request).to have_attributes(proxy_request: true, request_type: "fetch_athlete",
            response_status: "binx_response", parameters: {"url" => "athlete/2430215"})
          expect(strava_request.request_method).to eq "GET"
          expect(strava_request.requested_at).to be_within(1).of Time.current
        end
      end

      context "activity detail response" do
        let(:detail_target_attributes) do
          target_attributes.except(:enriched_at).merge(
            description: "Hawk with Eric and Scott and cedar",
            kudos_count: 22,
            photos: {
              photo_url: "https://dgtzuqphqg23d.cloudfront.net/AdftI2Cg62i6LQOs6W5N3iX67FhZCCr6-F0BdwkwUvw-768x576.jpg",
              photo_count: 2
            },
            segment_locations: {
              locations: [
                {city: "San Francisco", region: "CA", country: "US"},
                {region: "CA", country: "US"},
                {city: "Mill Valley", region: "CA", country: "US"}
              ],
              regions: {"California" => "CA"},
              countries: {"United States" => "US"}
            },
            strava_data: target_attributes[:strava_data].merge(muted: false)
          )
        end

        it "enriches from detail" do
          VCR.use_cassette("strava-get_activity") do
            expect {
              post base_url, params: {url: "activities/17323701543", method: "GET", access_token: doorkeeper_token.token}
            }.to change(StravaActivity, :count).by(1)
            expect(response.status).to eq 200
            expect(json_result["title"]).to eq "Thanks for coming across the bay!"
            expect(json_result["description"]).to eq "Hawk with Eric and Scott and cedar"
          end

          strava_activity = StravaActivity.last
          expect(strava_activity.enriched?).to be_truthy
          expect(strava_activity.enriched_at).to be_within(2.seconds).of(Time.current)
          expect(strava_activity).to have_attributes detail_target_attributes.as_json
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
                url: "activities/#{strava_id}", method: "PUT", access_token: doorkeeper_token.token, body: {gear_id:}
              }
            }.to change(StravaRequest, :count).by(1)
          end

          expect(response.status).to eq 404
          expect(json_result["message"]).to eq "Resource Not Found"
          expect(json_result["errors"]).to be_present

          strava_request = StravaRequest.last
          expect(strava_request.proxy_request?).to be_truthy
          expect(strava_request.update_activity?).to be_truthy
          expect(strava_request.response_status).to eq "insufficient_token_privileges"
          expect(strava_request.parameters).to eq expected_parameters.as_json
          expect(strava_request.request_method).to eq "PUT"

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
              photos: {photo_url: "https://dgtzuqphqg23d.cloudfront.net/lDHfSHn0XR7kn5dltGzfOIgJlAdwjgqM4_6HbGt95l4-768x432.jpg", photo_count: 1},
              segment_locations: {},
              activity_type: "Ride",
              timezone: "America/Chicago",
              average_speed: 8.466,
              suffer_score: 2.0,
              strava_data: {
                commute: false,
                trainer: true,
                muted: true,
                pr_count: 0,
                device_name: "Peloton Bike",
                device_watts: true,
                average_speed: 8.466,
                average_watts: 156.0,
                max_heartrate: 149.0,
                average_heartrate: 136.2
              }
            }
          end
          it "updates the activity and runs update_from_strava!" do
            expect(strava_integration.reload.token_expired?).to be_falsey
            og_token = strava_integration.access_token
            expect(strava_activity.reload.enriched?).to be_falsey

            VCR.use_cassette("strava-proxy_update_activity") do
              expect {
                post base_url, params: {
                  url: "activities/#{strava_id}", method: "PUT", access_token: doorkeeper_token.token, body: {gear_id:}
                }
              }.to change(StravaRequest, :count).by(2)
              # proxy PUT + update_from_strava! GET + enqueued gear fetch
            end

            expect(response.status).to eq 200
            expect(strava_integration.access_token).to eq og_token

            strava_proxy_request = StravaRequest.where(proxy_request: true, request_type: :update_activity).last
            expect(strava_proxy_request.success?).to be_truthy
            expect(strava_proxy_request.parameters).to eq expected_parameters.as_json

            fetch_request = StravaRequest.where(request_type: :fetch_activity).last
            expect(fetch_request.success?).to be_truthy

            expect(strava_activity.reload.enriched?).to be_truthy
            expect(strava_activity).to have_attributes target_attributes.as_json
            expect(strava_activity.start_date).to be_within(1).of Time.at(1771267927)
            expect(json_result).to eq strava_activity.proxy_serialized.as_json
          end
        end
      end

      context "strava returns rate limit error" do
        it "returns strava error status" do
          VCR.use_cassette("strava-proxy_rate_limited") do
            expect do
              post base_url, params: {url: "activities/6969", method: "GET", access_token: doorkeeper_token.token}
            end.to change(StravaRequest, :count).by 1
            expect(response.status).to eq 429
            expect(json_result["message"]).to eq "Rate Limit Exceeded"
            expect(json_result["errors"]).to be_present

            strava_request = StravaRequest.last
            expect(strava_request).to have_attributes(proxy_request: true, request_type: "fetch_activity",
              response_status: "rate_limited", parameters: {"url" => "activities/6969"})
            expect(strava_request.requested_at).to be_within(1).of Time.current
          end
        end
      end

      context "pre-emptively rate limited (binx_response_rate_limited)" do
        let(:boundary) { Time.current.change(min: (Time.current.min / 15) * 15, sec: 0) }
        let(:rate_limit) do
          {short_limit: 200, short_usage: 198, long_limit: 2000, long_usage: 0,
           read_short_limit: 200, read_short_usage: 198, read_long_limit: 2000, read_long_usage: 0}
        end
        let!(:rate_limit_request) do
          FactoryBot.create(:strava_request, :processed, strava_integration:,
            requested_at: boundary + 1.second, rate_limit:)
        end

        it "returns 429 with rate limit message without calling Strava" do
          expect do
            post base_url, params: {url: "activities/17323701543", method: "GET", access_token: doorkeeper_token.token}
          end.to change(StravaRequest, :count).by 1
          expect(response.status).to eq 429
          expect(json_result["message"]).to eq "Rate Limit Exceeded"
          expect(json_result["errors"]).to be_present
          expect(StravaRequest.last.binx_response_rate_limited?).to be_truthy
        end
      end

      context "strava returns not found" do
        let(:expected_response_body) { {message: "Record Not Found", errors: [{resource: "resource", field: "path", code: "invalid"}]} }
        it "returns strava error status" do
          VCR.use_cassette("strava-proxy_not_found") do
            expect do
              post base_url, params: {url: "activities/3333/dddd", method: "GET", access_token: doorkeeper_token.token}
            end.to change(StravaRequest, :count).by 1
            expect(response.status).to eq 404
            expect(json_result).to eq expected_response_body.as_json

            strava_request = StravaRequest.last
            expect(strava_request).to have_attributes(proxy_request: true, request_type: "fetch_activity",
              response_status: "error", parameters: {"url" => "activities/3333/dddd", "error_response_status" => 404})
            expect(strava_request.requested_at).to be_within(1).of Time.current
          end
        end
      end

      context "strava returns server error" do
        it "returns strava error status without raising" do
          VCR.use_cassette("strava-proxy_server_error") do
            expect do
              post base_url, params: {url: "activities/6969", method: "GET", access_token: doorkeeper_token.token}
            end.to change(StravaRequest, :count).by 1
            expect(response.status).to eq 500
            expect(json_result["message"]).to eq "Internal Server Error"

            strava_request = StravaRequest.last
            expect(strava_request).to have_attributes(response_status: "error", request_type: "fetch_activity",
              proxy_request: true, parameters: {"url" => "activities/6969", "error_response_status" => 500})
            expect(strava_request.requested_at).to be_within(1).of Time.current
          end
        end
      end

      context "enriched_since request" do
        let!(:enriched_activity) do
          FactoryBot.create(:strava_activity, :enriched, strava_integration:, strava_id: "111")
        end
        let!(:old_enriched_activity) do
          FactoryBot.create(:strava_activity, strava_integration:, strava_id: "222",
            enriched_at: Time.current - 2.hours)
        end
        let!(:unenriched_activity) do
          FactoryBot.create(:strava_activity, strava_integration:, strava_id: "333")
        end
        let(:enriched_since_timestamp) { 1.hour.ago.to_i }

        it "returns only recently enriched activities from local DB" do
          expect {
            post base_url, params: {
              url: "athlete/activities?enriched_since=#{enriched_since_timestamp}",
              method: "GET", access_token: doorkeeper_token.token
            }
          }.to_not change(StravaRequest, :count)

          expect(response.status).to eq 200
          expect(json_result).to be_a(Array)
          expect(json_result.length).to eq 1
          expect(json_result.first["strava_id"]).to eq "111"
          expect(json_result.first["enriched_at"]).to be_present
        end
      end

      context "invalid proxy path" do
        it "rejects absolute URLs" do
          expect do
            post base_url, params: {url: "https://evil.com/steal", method: "GET", access_token: doorkeeper_token.token}
          end.to_not change(StravaRequest, :count)
          expect(response.status).to eq 400
        end

        it "rejects protocol-relative URLs" do
          expect do
            post base_url, params: {url: "//evil.com/steal", method: "GET", access_token: doorkeeper_token.token}
          end.to_not change(StravaRequest, :count)
          expect(response.status).to eq 400
        end

        it "rejects path traversal" do
          expect do
            post base_url, params: {url: "../../oauth/token", method: "GET", access_token: doorkeeper_token.token}
          end.to_not change(StravaRequest, :count)
          expect(response.status).to eq 400
        end
      end
    end
  end

  describe "CORS headers" do
    context "with allowed origin" do
      it "sets CORS headers" do
        post base_url, params: {url: "athlete/activities", method: "GET"},
          headers: {"Origin" => "https://bikeindex.org"}
        expect(response.headers["Access-Control-Allow-Origin"]).to eq "https://bikeindex.org"
        expect(response.headers["Access-Control-Allow-Methods"]).to eq "POST, OPTIONS"
        expect(response.headers["Access-Control-Allow-Headers"]).to include "Authorization"
      end
    end

    context "with www subdomain origin" do
      it "sets CORS headers" do
        post base_url, params: {url: "athlete/activities", method: "GET"},
          headers: {"Origin" => "https://www.bikeindex.org"}
        expect(response.headers["Access-Control-Allow-Origin"]).to eq "https://www.bikeindex.org"
      end
    end

    context "with disallowed origin" do
      it "defaults to first allowed origin" do
        post base_url, params: {url: "athlete/activities", method: "GET"},
          headers: {"Origin" => "https://evil.com"}
        expect(response.headers["Access-Control-Allow-Origin"]).to eq "https://bikeindex.org"
      end
    end
  end
end
