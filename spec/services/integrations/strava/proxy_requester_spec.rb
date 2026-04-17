# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Strava::ProxyRequester do
  before { StravaRequest.destroy_all }

  let(:strava_integration) { FactoryBot.create(:strava_integration) }
  let(:user) { strava_integration.user }

  describe ".authorize_user_and_strava_integration" do
    let(:doorkeeper_app) { FactoryBot.create(:doorkeeper_app) }
    let(:access_token) { Doorkeeper::AccessToken.create!(application_id: doorkeeper_app.id, resource_owner_id: user.id) }
    before { ENV["STRAVA_DOORKEEPER_APP_ID"] = doorkeeper_app.id.to_s }

    it "returns user and strava_integration when valid" do
      result = described_class.authorize_user_and_strava_integration(access_token)
      expect(result[:error]).to be_nil
      expect(result[:user]).to eq user
      expect(result[:strava_integration]).to eq strava_integration
    end
  end

  describe ".sync_status" do
    it "returns sync_status hash for the integration" do
      expect(strava_integration.synced?).to be_falsey
      result = described_class.sync_status(strava_integration)
      expect(result[:sync_status][:status]).to eq "pending"
      expect(result[:sync_status]).to have_key(:activities_downloaded_count)
      expect(result[:sync_status]).to have_key(:progress_percent)
      expect(result[:sync_status]).to have_key(:rate_limited)
    end

    it "includes rate_limited based on rate limit headroom" do
      allow(StravaJobs::ScheduledRequestEnqueuer).to receive(:rate_limit_allows_batch?).and_return(false)
      result = described_class.sync_status(strava_integration)
      expect(result[:sync_status][:rate_limited]).to be true

      allow(StravaJobs::ScheduledRequestEnqueuer).to receive(:rate_limit_allows_batch?).and_return(true)
      result = described_class.sync_status(strava_integration)
      expect(result[:sync_status][:rate_limited]).to be false
    end
  end

  describe ".find_or_create_access_token" do
    let(:doorkeeper_app) { FactoryBot.create(:doorkeeper_app) }
    before { ENV["STRAVA_DOORKEEPER_APP_ID"] = doorkeeper_app.id.to_s }

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

  describe ".proxy_request_type" do
    it "returns update_activity for non-GET methods" do
      expect(described_class.send(:proxy_request_type, "activities/123", "PUT")).to eq :update_activity
      expect(described_class.send(:proxy_request_type, "activities/123", "POST")).to eq :update_activity
    end

    it "returns fetch_athlete for athlete URLs" do
      expect(described_class.send(:proxy_request_type, "athlete", nil)).to eq :fetch_athlete
      expect(described_class.send(:proxy_request_type, "athlete/2430215", nil)).to eq :fetch_athlete
    end

    it "returns list_activities for paginated activity list URLs" do
      expect(described_class.send(:proxy_request_type, "athlete/activities?page=1", nil)).to eq :list_activities
      expect(described_class.send(:proxy_request_type, "athlete/activities?per_page=30&page=2", nil)).to eq :list_activities
    end

    it "returns fetch_activity for activity URLs" do
      expect(described_class.send(:proxy_request_type, "activities/17323701543", nil)).to eq :fetch_activity
      expect(described_class.send(:proxy_request_type, "activities/3333333", nil)).to eq :fetch_activity
    end

    it "returns fetch_gear for gear URLs" do
      expect(described_class.send(:proxy_request_type, "gear/b12345", nil)).to eq :fetch_gear
    end

    it "raises for unknown URLs" do
      expect { described_class.send(:proxy_request_type, "segments/12345", nil) }.to raise_error(ArgumentError, /Unknown proxy request type/)
    end
  end

  describe "validate_url!" do
    ["javascript://evil.com", "../etc/passwd", "/foo/../../etc", "//strava"].each do |invalid_url|
      it "raises" do
        expect { described_class.send(:validate_url!, invalid_url) }.to raise_error("Invalid proxy path")
      end
    end
    it "is valid" do
      expect(described_class.send(:validate_url!, "athlete/123")).to be_nil
      expect(described_class.send(:validate_url!, "athlete/activities")).to be_nil
      expect(described_class.send(:validate_url!, "activities/123")).to be_nil
    end
  end

  describe ".create_and_execute" do
    before { FactoryBot.create(:state_california) }
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

    context "activity detail" do
      let(:detail_target_attributes) do
        target_attributes.merge(
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
          strava_data: target_attributes["strava_data"].merge("muted" => false)
        ).as_json
      end

      it "creates from list then enriches from detail" do
        result = nil
        VCR.use_cassette("strava-get_activity") do
          expect {
            result = described_class.create_and_execute(strava_integration:, user:, url: "activities/17323701543", method: "GET")
            expect(result[:status]).to eq 200
          }.to change(StravaActivity, :count).by(1)
        end

        strava_request = StravaRequest.last
        expect(strava_request.success?).to be_truthy

        strava_activity = StravaActivity.last
        expect(strava_activity.enriched?).to be_truthy
        expect(strava_activity.enriched_at).to be_within(2.seconds).of(Time.current)
        expect(strava_activity).to have_attributes detail_target_attributes
        expect(result[:json]).to eq strava_activity.proxy_serialized

        VCR.use_cassette("strava-get_activity") do
          expect {
            described_class.create_and_execute(strava_integration:, user:, url: "activities/17323701543", method: "GET")
          }.to_not change(StravaActivity, :count)
        end
      end
    end

    context "when RequestRunner is rate limited" do
      let(:boundary) { Time.current.change(min: (Time.current.min / 15) * 15, sec: 0) }
      let!(:rate_limit_request) do
        FactoryBot.create(:strava_request, :processed, strava_integration:,
          requested_at: boundary + 1.second,
          rate_limit: {short_limit: 200, short_usage: 198, long_limit: 2000, long_usage: 0,
                       read_short_limit: 200, read_short_usage: 198, read_long_limit: 2000, read_long_usage: 0})
      end

      it "returns 429 when RequestRunner detects rate limiting" do
        result = described_class.create_and_execute(strava_integration:, user:, url: "activities/17323701543", method: "GET")
        expect(result[:status]).to eq 429
        expect(result[:json]["message"]).to eq "Rate Limit Exceeded"
        expect(StravaActivity.count).to eq 0
      end
    end

    context "rate limited response" do
      it "marks request as rate_limited" do
        VCR.use_cassette("strava-proxy_rate_limited") do
          result = described_class.create_and_execute(strava_integration:, user:, url: "activities/6969", method: "GET")
          strava_request = StravaRequest.last
          expect(strava_request.rate_limited?).to be_truthy
          expect(result[:status]).to eq 429
        end
        expect(StravaActivity.count).to eq 0
      end
    end

    context "server error response" do
      it "marks request as error without raising" do
        VCR.use_cassette("strava-proxy_server_error") do
          result = described_class.create_and_execute(strava_integration:, user:, url: "activities/6969", method: "GET")
          strava_request = StravaRequest.last
          expect(strava_request.error?).to be_truthy
          expect(result[:status]).to eq 500
        end
        expect(StravaActivity.count).to eq 0
      end
    end
  end
end
