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

          activity = strava_integration.strava_activities.find_by(strava_id: "123")
          expect(activity.title).to eq "Morning Ride"
          expect(activity.sport_type).to eq "Ride"
        end
      end
    end

    context "activity detail" do
      it "creates or updates the activity" do
        VCR.use_cassette("strava-proxy_activity_detail") do
          expect {
            result = described_class.create_and_execute(strava_integration:, user:, url: "activities/456", method: "GET")
            expect(result[:strava_request].success?).to be_truthy
            expect(result[:response].status).to eq 200
          }.to change(StravaRequest, :count).by(1)
            .and change(StravaActivity, :count).by(1)

          activity = strava_integration.strava_activities.find_by(strava_id: "456")
          expect(activity.title).to eq "Evening Ride"
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
