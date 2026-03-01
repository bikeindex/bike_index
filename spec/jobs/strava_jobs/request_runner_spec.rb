# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaJobs::RequestRunner, type: :job do
  before { StravaRequest.destroy_all } # required because it's the analytics db
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  let(:instance) { described_class.new }

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
    expect(described_class.frequency).to eq(16.seconds)
  end

  describe "perform with no args (enqueue_next_request)" do
    it "does nothing when no pending requests" do
      instance.perform
      expect(described_class.jobs.size).to eq(0)
    end

    context "with pending requests" do
      let(:strava_integration) { FactoryBot.create(:strava_integration) }

      it "enqueues a job with the request id" do
        strava_request = StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id, request_type: :list_activities)
        instance.perform
        expect(described_class.jobs.size).to eq(1)
        expect(described_class.jobs.first["args"]).to eq([strava_request.id])
      end

      it "enqueues up to BATCH_SIZE requests" do
        30.times.map do
          StravaRequest.create!(user_id: strava_integration.user_id,
            strava_integration_id: strava_integration.id, request_type: :fetch_activity,
            parameters: {strava_id: "123"})
        end
        instance.perform
        expect(described_class.jobs.size).to eq(described_class::BATCH_SIZE)
      end

      it "enqueues in priority order: list_activities, fetch_gear, fetch_activity" do
        fetch_activity = StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id, request_type: :fetch_activity,
          parameters: {strava_id: "123"})
        list_activities = StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id, request_type: :list_activities,
          parameters: {page: 1})
        fetch_gear = StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id, request_type: :fetch_gear,
          parameters: {strava_gear_id: "b123"})

        instance.perform
        enqueued_ids = described_class.jobs.map { |j| j["args"].first }
        expect(enqueued_ids).to eq([list_activities.id, fetch_gear.id, fetch_activity.id])
      end

      it "skips enqueue when read short rate limit headroom is insufficient" do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id, request_type: :list_activities)
        allow(StravaRequest).to receive(:estimated_current_rate_limit).and_return(
          {"read_short_limit" => 100, "read_short_usage" => 95, "read_long_limit" => 1000, "read_long_usage" => 200}
        )
        instance.perform
        expect(described_class.jobs.size).to eq(0)
      end

      it "skips enqueue when read long rate limit headroom is insufficient" do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id, request_type: :list_activities)
        allow(StravaRequest).to receive(:estimated_current_rate_limit).and_return(
          {"read_short_limit" => 200, "read_short_usage" => 0, "read_long_limit" => 1000, "read_long_usage" => 995}
        )
        instance.perform
        expect(described_class.jobs.size).to eq(0)
      end
    end
  end

  describe "perform with strava_request_id" do
    let(:strava_integration) do
      FactoryBot.create(:strava_integration, :syncing,
        athlete_id: ENV["STRAVA_TEST_USER_ID"], athlete_activity_count: 1817)
    end
    let(:strava_request) do
      StravaRequest.create!(user_id: strava_integration.user_id,
        strava_integration_id: strava_integration.id,
        request_type: :list_activities)
    end

    context "with list_activities request" do
      it "creates activities and enqueues detail requests for cycling activities" do
        VCR.use_cassette("strava-list_activities") do
          expect { instance.perform(strava_request.id) }.to change(StravaRequest, :count).by 3
        end

        strava_request.reload
        expect(strava_request.response_status).to eq("success")
        expect(strava_integration.strava_activities.count).to be > 0

        strava_activity = strava_integration.strava_activities.first
        expect(Binxtils::TimeZoneParser.parse("(GMT-08:00) America/Los_Angeles").name).to eq "America/Los_Angeles"
        expect(strava_activity).to have_attributes({
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
          }.as_json
        })
        expect(strava_activity.start_date).to be_within(1).of Binxtils::TimeParser.parse("2026-02-07T23:39:36Z")

        cycling_count = strava_integration.strava_activities.cycling.count
        detail_requests = StravaRequest.where(strava_integration_id: strava_integration.id, request_type: :fetch_activity)
        expect(detail_requests.count).to eq(cycling_count)
      end
      context "with list_activities over pages enabled" do
        let(:strava_request) do
          StravaRequest.create(strava_integration_id: strava_integration.id, user_id: strava_integration.user_id,
            request_type: :list_activities, parameters: {page: 13})
        end
        it "is successful but creates no new requests" do
          expect(strava_request.reload.looks_like_last_page?).to be_truthy

          VCR.use_cassette("strava-list_activities-last_page") do
            expect { instance.perform(strava_request.id) }
              .to_not change(StravaRequest, :count)
          end

          expect(StravaActivity.count).to eq 0
        end
      end
    end

    context "with fetch_activity request" do
      before { FactoryBot.create(:state_california) }
      let!(:strava_activity) do
        FactoryBot.create(:strava_activity, strava_integration:, strava_id: "17323701543")
      end
      let!(:strava_request) do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :fetch_activity,
          parameters: {strava_id: strava_activity.strava_id})
      end
      let(:target_attributes) do
        {
          description: "Hawk with Eric and Scott and cedar",
          average_speed: 4.746,
          suffer_score: 27.0,
          kudos_count: 22,
          photos: {
            photo_url: "https://dgtzuqphqg23d.cloudfront.net/AdftI2Cg62i6LQOs6W5N3iX67FhZCCr6-F0BdwkwUvw-768x576.jpg",
            photo_count: 2
          },
          strava_data: {
            average_heartrate: 115.0, max_heartrate: 167.0,
            device_name: "Strava App", commute: false,
            average_speed: 4.746, pr_count: 0,
            average_watts: 129.0, device_watts: false,
            muted: false, trainer: false
          },
          segment_locations: {
            locations: [
              {city: "San Francisco", region: "CA", country: "US"},
              {region: "CA", country: "US"},
              {city: "Mill Valley", region: "CA", country: "US"}
            ],
            regions: {"California" => "CA"},
            countries: {"United States" => "US"}
          }
        }.as_json
      end

      it "updates activity details and finishes sync when last" do
        VCR.use_cassette("strava-get_activity") do
          instance.perform(strava_request.id)
        end

        strava_request.reload
        expect(strava_request.response_status).to eq("success")
        strava_integration.reload
        expect(strava_integration.status).to eq("synced")

        expect(strava_activity.reload.enriched?).to be_truthy
        expect(strava_activity).to have_attributes target_attributes
      end
    end

    context "with fetch_gear request" do
      let!(:strava_gear) do
        FactoryBot.create(:strava_gear, strava_integration:,
          strava_gear_id: "b12345", strava_data: {"resource_state" => 2})
      end
      let!(:strava_request) do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :fetch_gear,
          parameters: {strava_gear_id: "b12345"})
      end

      it "updates gear from detail response" do
        VCR.use_cassette("strava-get_gear") do
          instance.perform(strava_request.id)
        end

        strava_request.reload
        expect(strava_request.response_status).to eq("success")
        strava_gear.reload
        expect(strava_gear.enriched?).to be true
        expect(strava_gear.last_updated_from_strava_at).to be_present
      end
    end

    context "with rate limited response" do
      it "sets response_status to rate_limited and creates a retry request" do
        strava_request_id = strava_request.id
        VCR.use_cassette("strava-rate_limited") do
          expect { instance.perform(strava_request_id) }.to change(StravaRequest, :count).by(1)
        end

        strava_request.reload
        expect(strava_request.requested_at).to be_present
        expect(strava_request.response_status).to eq("rate_limited")
        expect(strava_request.rate_limit).to eq({"short_limit" => 100, "short_usage" => 101, "long_limit" => 1000, "long_usage" => 350,
          "read_short_limit" => 100, "read_short_usage" => 101, "read_long_limit" => 1000, "read_long_usage" => 350})

        retry_request = StravaRequest.last
        expect(retry_request.request_type).to eq(strava_request.request_type)
        expect(retry_request.requested_at).to be_nil
      end
    end

    context "with unauthorized response" do
      it "sets response_status to token_refresh_failed" do
        VCR.use_cassette("strava-unauthorized") do
          instance.perform(strava_request.id)
        end

        strava_request.reload
        expect(strava_request.requested_at).to be_present
        expect(strava_request.response_status).to eq("token_refresh_failed")
      end
    end

    context "with server error response" do
      it "raises and sets response_status to error" do
        VCR.use_cassette("strava-server_error") do
          expect { instance.perform(strava_request.id) }.to raise_error(/Strava API error 500/)
        end

        strava_request.reload
        expect(strava_request.requested_at).to be_present
        expect(strava_request.response_status).to eq("error")
      end
    end

    context "with missing strava_integration" do
      let!(:strava_request) do
        StravaRequest.create!(user_id: 1, strava_integration_id: -1, request_type: :list_activities)
      end

      it "marks request as integration_deleted without setting requested_at" do
        instance.perform(strava_request.id)

        strava_request.reload
        expect(strava_request.requested_at).to be_nil
        expect(strava_request.response_status).to eq("integration_deleted")
        expect(StravaRequest.unprocessed).not_to include(strava_request)
      end
    end

    context "with incoming_webhook activity create" do
      let!(:strava_request) do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :incoming_webhook,
          parameters: {"object_type" => "activity", "aspect_type" => "create",
                       "object_id" => "17323701543", "owner_id" => strava_integration.athlete_id})
      end

      it "creates a fetch_activity StravaRequest instead of fetching immediately" do
        expect { instance.perform(strava_request.id) }.to change(StravaRequest, :count).by(1)

        strava_request.reload
        expect(strava_request.response_status).to eq("success")

        fetch_request = StravaRequest.where(request_type: :fetch_activity).last
        expect(fetch_request.strava_integration_id).to eq(strava_integration.id)
        expect(fetch_request.parameters["strava_id"]).to eq("17323701543")
      end
    end

    context "with incoming_webhook activity update" do
      let!(:existing_activity) do
        FactoryBot.create(:strava_activity, strava_integration:, strava_id: "17323701543")
      end
      let!(:strava_request) do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :incoming_webhook,
          parameters: {"object_type" => "activity", "aspect_type" => "update",
                       "object_id" => "17323701543", "owner_id" => strava_integration.athlete_id})
      end

      it "creates a fetch_activity StravaRequest instead of fetching immediately" do
        expect { instance.perform(strava_request.id) }.to change(StravaRequest, :count).by(1)

        strava_request.reload
        expect(strava_request.response_status).to eq("success")

        fetch_request = StravaRequest.where(request_type: :fetch_activity).last
        expect(fetch_request.strava_integration_id).to eq(strava_integration.id)
        expect(fetch_request.parameters["strava_id"]).to eq("17323701543")
      end
    end

    context "with incoming_webhook activity delete" do
      let!(:existing_activity) do
        FactoryBot.create(:strava_activity, strava_integration:, strava_id: "17323701543")
      end
      let!(:strava_request) do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :incoming_webhook,
          parameters: {"object_type" => "activity", "aspect_type" => "delete",
                       "object_id" => "17323701543", "owner_id" => strava_integration.athlete_id})
      end

      it "destroys the StravaActivity" do
        expect { instance.perform(strava_request.id) }.to change(StravaActivity, :count).by(-1)

        strava_request.reload
        expect(strava_request.response_status).to eq("success")
        expect(strava_integration.strava_activities.find_by(strava_id: "17323701543")).to be_nil
      end
    end

    context "with incoming_webhook athlete deauth" do
      let!(:strava_request) do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :incoming_webhook,
          parameters: {"object_type" => "athlete", "aspect_type" => "update",
                       "owner_id" => strava_integration.athlete_id,
                       "updates" => {"authorized" => "false"}})
      end

      it "soft-deletes the integration" do
        instance.perform(strava_request.id)

        strava_request.reload
        expect(strava_request.response_status).to eq("success")
        expect(StravaIntegration.find_by(id: strava_integration.id)).to be_nil
        expect(StravaIntegration.unscoped.find_by(id: strava_integration.id)).to be_present
      end
    end

    context "with already processed request" do
      let!(:strava_request) do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :list_activities,
          requested_at: Time.current, response_status: :success)
      end

      it "skips the request" do
        instance.perform(strava_request.id)
      end
    end
  end
end
