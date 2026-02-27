# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaJobs::ProxyRequester do
  before { StravaRequest.destroy_all }

  let(:strava_integration) { FactoryBot.create(:strava_integration) }
  let(:user) { strava_integration.user }

  describe ".authorize_user_and_strava_integration" do
    let(:doorkeeper_app) { FactoryBot.create(:doorkeeper_app) }
    let(:access_token) { Doorkeeper::AccessToken.create!(application_id: doorkeeper_app.id, resource_owner_id: user.id) }
    before { stub_const("StravaJobs::ProxyRequester::STRAVA_DOORKEEPER_APP_ID", doorkeeper_app.id) }

    it "returns sync_status when strava integration is not synced" do
      expect(strava_integration.synced?).to be_falsey
      result = described_class.authorize_user_and_strava_integration(access_token)
      expect(result[:error]).to be_nil
      expect(result[:user]).to be_nil
      expect(result[:sync_status][:status]).to eq "pending"
      expect(result[:sync_status]).to have_key(:activities_downloaded_count)
      expect(result[:sync_status]).to have_key(:progress_percent)
    end

    it "returns user and strava_integration when valid" do
      strava_integration.update!(status: :synced)
      result = described_class.authorize_user_and_strava_integration(access_token)
      expect(result[:error]).to be_nil
      expect(result[:user]).to eq user
      expect(result[:strava_integration]).to eq strava_integration
    end
  end

  describe ".find_or_create_access_token" do
    let(:doorkeeper_app) { FactoryBot.create(:doorkeeper_app) }
    before { stub_const("StravaJobs::ProxyRequester::STRAVA_DOORKEEPER_APP_ID", doorkeeper_app.id) }

    it "returns existing valid token" do
      existing_token = Doorkeeper::AccessToken.create!(
        application_id: doorkeeper_app.id,
        resource_owner_id: user.id,
        scopes: "public",
        expires_in: Doorkeeper.configuration.access_token_expires_in
      )

      expect {
        result = described_class.find_or_create_access_token(user.id)
        expect(result.token).to eq existing_token.token
      }.not_to change(Doorkeeper::AccessToken, :count)
    end

    it "creates a new token when none exists" do
      expect {
        result = described_class.find_or_create_access_token(user.id)
        expect(result).to be_accessible
        expect(result.application_id).to eq doorkeeper_app.id
        expect(result.resource_owner_id).to eq user.id
      }.to change(Doorkeeper::AccessToken, :count).by(1)
    end

    it "revokes expired token and creates a new one" do
      expired_token = Doorkeeper::AccessToken.create!(
        application_id: doorkeeper_app.id,
        resource_owner_id: user.id,
        scopes: "public",
        expires_in: 3600,
        created_at: 2.hours.ago
      )

      expect {
        result = described_class.find_or_create_access_token(user.id)
        expect(result.token).not_to eq expired_token.token
        expect(result).to be_accessible
      }.to change(Doorkeeper::AccessToken, :count).by(1)

      expect(expired_token.reload.revoked?).to be true
    end
  end

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
          average_watts: 129.0, device_watts: false,
          trainer: false
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
          strava_data: target_attributes["strava_data"].merge("muted" => false)
        ).as_json
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
        expect(strava_activity.enriched_at).to be_within(2.seconds).of(Time.current)
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
          expect(result[:strava_request].parameters).to eq("url" => "athlete/activities?page=1&per_page=1")
        end
      end
    end
  end
end
