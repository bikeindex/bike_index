# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaJobs::ProxyRequest do
  before { StravaRequest.destroy_all }

  let(:strava_integration) { FactoryBot.create(:strava_integration) }
  let(:user) { strava_integration.user }

  describe ".create_and_execute" do
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

    context "activities list" do
      it "creates strava_request, stores activities, returns serialized response" do
        result = nil
        VCR.use_cassette("strava-list_activities") do
          expect {
            result = described_class.create_and_execute(strava_integration:, user:, url: "athlete/activities?page=1&per_page=1", method: "GET")
            expect(result[:strava_request]).to be_a(StravaRequest)
            expect(result[:strava_request].success?).to be_truthy
            expect(result[:strava_request].proxy?).to be_truthy
            expect(result[:strava_request].parameters).to eq("url" => "athlete/activities?page=1&per_page=1", "method" => "GET")
            expect(result[:response].status).to eq 200
          }.to change(StravaRequest, :count).by(1)
            .and change(StravaActivity, :count).by(1)

          strava_activity = strava_integration.strava_activities.find_by(strava_id: "17323701543")
          expect(strava_activity).to have_attributes target_attributes
          expect(strava_activity.start_date).to be_within(1).of Binxtils::TimeParser.parse("2026-02-07T23:39:36Z")
          expect(result[:serialized]).to eq [strava_activity.proxy_serialized]
        end
      end
    end

    context "activity detail" do
      let(:detail_target_attributes) do
        target_attributes.merge(
          "description" => "Hawk with Eric and Scott and cedar",
          "photos" => {
            "photo_url" => "https://dgtzuqphqg23d.cloudfront.net/AdftI2Cg62i6LQOs6W5N3iX67FhZCCr6-F0BdwkwUvw-768x576.jpg",
            "photo_count" => 2
          },
          "segment_locations" => {
            "cities" => ["San Francisco", "Mill Valley"],
            "states" => ["California"],
            "countries" => ["United States", "USA"]
          },
          "strava_data" => target_attributes["strava_data"].merge("enriched" => true)
        )
      end

      it "creates from list then enriches from detail" do
        VCR.use_cassette("strava-list_activities") do
          described_class.create_and_execute(strava_integration:, user:, url: "athlete/activities?page=1&per_page=1", method: "GET")
        end
        strava_activity = strava_integration.strava_activities.find_by(strava_id: "17323701543")
        expect(strava_activity).to have_attributes target_attributes
        expect(strava_activity.enriched?).to be_falsey

        result = nil
        VCR.use_cassette("strava-get_activity") do
          expect {
            result = described_class.create_and_execute(strava_integration:, user:, url: "activities/17323701543", method: "GET")
            expect(result[:strava_request].success?).to be_truthy
            expect(result[:response].status).to eq 200
          }.to_not change(StravaActivity, :count)
        end
        strava_activity.reload
        expect(strava_activity.enriched?).to be_truthy
        expect(strava_activity).to have_attributes detail_target_attributes
        expect(result[:serialized]).to eq strava_activity.proxy_serialized
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
        VCR.use_cassette("strava-list_activities") do
          result = described_class.create_and_execute(strava_integration:, user:, url: "athlete/activities?page=1&per_page=1")
          expect(result[:strava_request].success?).to be_truthy
          expect(result[:strava_request].parameters).to eq("url" => "athlete/activities?page=1&per_page=1", "method" => nil)
        end
      end
    end
  end
end
