# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaJobs::ProxyRequest do
  before { StravaRequest.destroy_all }

  let(:strava_integration) { FactoryBot.create(:strava_integration) }
  let(:user) { strava_integration.user }

  describe ".create_and_execute" do
    context "activities list" do
      it "creates strava_request, stores activities, returns response" do
        VCR.use_cassette("strava-proxy_activities") do
          expect {
            result = described_class.create_and_execute(strava_integration:, user:, url: "athlete/activities", method: "GET")
            expect(result[:strava_request]).to be_a(StravaRequest)
            expect(result[:strava_request].success?).to be_truthy
            expect(result[:strava_request].proxy?).to be_truthy
            expect(result[:strava_request].parameters).to eq("url" => "athlete/activities", "method" => "GET")
            expect(result[:response].status).to eq 200
          }.to change(StravaRequest, :count).by(1)
            .and change(StravaActivity, :count).by(1)

          strava_activity = strava_integration.strava_activities.find_by(strava_id: "123")
          expect(strava_activity.title).to eq "Morning Ride"
          expect(strava_activity.sport_type).to eq "Ride"
        end
      end
    end

    context "activity detail" do
      it "creates or updates the activity with detail attributes" do
        VCR.use_cassette("strava-get_activity") do
          expect {
            result = described_class.create_and_execute(strava_integration:, user:, url: "activities/17323701543", method: "GET")
            expect(result[:strava_request].success?).to be_truthy
            expect(result[:response].status).to eq 200
          }.to change(StravaRequest, :count).by(1)
            .and change(StravaActivity, :count).by(1)

          strava_activity = strava_integration.strava_activities.find_by(strava_id: "17323701543")
          expect(strava_activity.enriched?).to be_truthy
          expect(strava_activity).to match_hash_indifferently(
            title: "Thanks for coming across the bay!",
            activity_type: "EBikeRide",
            sport_type: "EBikeRide",
            description: "Hawk with Eric and Scott and cedar",
            average_speed: 4.746,
            suffer_score: 27.0,
            kudos_count: 17,
            photos: {
              photo_url: "https://dgtzuqphqg23d.cloudfront.net/AdftI2Cg62i6LQOs6W5N3iX67FhZCCr6-F0BdwkwUvw-768x576.jpg",
              photo_count: 2
            },
            strava_data: {
              average_heartrate: 115.0, max_heartrate: 167.0,
              device_name: "Strava App", commute: false,
              average_speed: 4.746, pr_count: 0,
              average_watts: 129.0, device_watts: false
            },
            segment_locations: {
              cities: ["San Francisco", "Mill Valley"],
              states: ["California"],
              countries: ["United States", "USA"]
            }
          )
        end
      end
    end

    context "rate limited response" do
      it "marks request as rate_limited" do
        VCR.use_cassette("strava-proxy_rate_limited") do
          result = described_class.create_and_execute(strava_integration:, user:, url: "athlete/activities", method: "GET")
          expect(result[:strava_request].rate_limited?).to be_truthy
          expect(result[:response].status).to eq 429
        end
        expect(StravaActivity.count).to eq 0
      end
    end

    context "server error response" do
      it "marks request as error without raising" do
        VCR.use_cassette("strava-proxy_server_error") do
          result = described_class.create_and_execute(strava_integration:, user:, url: "athlete/activities", method: "GET")
          expect(result[:strava_request].error?).to be_truthy
          expect(result[:response].status).to eq 500
        end
        expect(StravaActivity.count).to eq 0
      end
    end

    context "nil method" do
      it "defaults to GET" do
        VCR.use_cassette("strava-proxy_activities") do
          result = described_class.create_and_execute(strava_integration:, user:, url: "athlete/activities")
          expect(result[:strava_request].success?).to be_truthy
          expect(result[:strava_request].parameters).to eq("url" => "athlete/activities", "method" => nil)
        end
      end
    end
  end
end
