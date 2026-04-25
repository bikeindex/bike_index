# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaJobs::RequestRunner, type: :job do
  before { StravaRequest.destroy_all } # required because it's the analytics db

  let(:instance) { described_class.new }

  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "droppable"
  end

  describe "redlock" do
    it "has correct key format" do
      expect(described_class.redlock_key(123)).to match(/StravaRequestRunnerLock-.*-123/)
    end

    context "when locked" do
      let(:strava_integration) do
        FactoryBot.create(:strava_integration, :syncing, status: :pending,
          strava_id: ENV["STRAVA_TEST_USER_ID"], athlete_activity_count: 1817)
      end
      let(:strava_request) do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :list_activities)
      end

      it "no-ops when redlock cannot be acquired" do
        lock_manager = described_class.new_lock_manager
        redlock = lock_manager.lock(described_class.redlock_key(strava_request.id), 30_000)

        begin
          instance.perform(strava_request.id)
          expect(strava_request.reload.response_status).to eq("pending")
        ensure
          lock_manager.unlock(redlock)
        end
      end
    end
  end

  describe "perform" do
    let(:strava_integration) do
      FactoryBot.create(:strava_integration, :syncing, status: :pending,
        strava_id: ENV["STRAVA_TEST_USER_ID"], athlete_activity_count: 1817)
    end
    let(:strava_request) do
      StravaRequest.create!(user_id: strava_integration.user_id,
        strava_integration_id: strava_integration.id,
        request_type: :list_activities)
    end

    context "with list_activities request" do
      it "creates activities and enqueues detail requests for cycling activities" do
        VCR.use_cassette("strava-list_activities") do
          instance.perform(strava_request.id)
        end
        StravaJobs::EnqueueEnrichActivities.drain

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
        expect(strava_integration.reload.status).to eq "synced"
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
          expect(strava_integration.reload.status).to eq "synced"
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
        FactoryBot.create(:strava_request, request_type: :list_activities, response_status: :success, strava_integration:)

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
          strava_id: "b12345", strava_data: {"resource_state" => 2})
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
        expect(strava_request).to have_attributes(proxy_request: false, response_status: "success",
          parameters: {"strava_gear_id" => "b12345"})
        expect(strava_request.requested_at).to be_within(1).of Time.current

        strava_gear.reload
        expect(strava_gear.enriched?).to be true
        expect(strava_gear.last_updated_from_strava_at).to be_present
      end
    end

    context "when currently_rate_limited? with request_type: :fetch_activity" do
      let!(:strava_request) do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :fetch_activity,
          parameters: {strava_id: "17323701543"})
      end
      let(:boundary) { Time.current.change(min: (Time.current.min / 15) * 15, sec: 0) }

      context "with list_activities request" do
        let!(:strava_request) do
          StravaRequest.create!(user_id: strava_integration.user_id,
            strava_integration_id: strava_integration.id,
            request_type: :list_activities)
        end
        let!(:rate_limit_request) do
          FactoryBot.create(:strava_request, :processed, strava_integration:,
            requested_at: boundary + 1.second,
            rate_limit: {short_limit: 200, short_usage: 0, long_limit: 2000, long_usage: 0,
                         read_short_limit: 200, read_short_usage: 110, read_long_limit: 2000, read_long_usage: 0})
        end

        it "proceeds despite fetch_activity rate limiting" do
          VCR.use_cassette("strava-list_activities") do
            instance.perform(strava_request.id)
          end

          strava_request.reload
          expect(strava_request.response_status).to eq("success")
        end
      end

      context "when short rate limit remaining is below threshold" do
        let!(:rate_limit_request) do
          FactoryBot.create(:strava_request, :processed, strava_integration:,
            requested_at: boundary + 1.second,
            rate_limit: {short_limit: 200, short_usage: 0, long_limit: 2000, long_usage: 0,
                         read_short_limit: 200, read_short_usage: 110, read_long_limit: 2000, read_long_usage: 0})
        end

        it "sets binx_response_rate_limited without calling Strava" do
          expect { instance.perform(strava_request.id) }.to change(StravaRequest, :count).by(1)

          strava_request.reload
          expect(strava_request.response_status).to eq("binx_response_rate_limited")
        end
      end

      context "when long rate limit remaining is below threshold" do
        let!(:rate_limit_request) do
          FactoryBot.create(:strava_request, :processed, strava_integration:,
            requested_at: boundary + 1.second,
            rate_limit: {short_limit: 200, short_usage: 0, long_limit: 2000, long_usage: 0,
                         read_short_limit: 200, read_short_usage: 0, read_long_limit: 2000, read_long_usage: 1600})
        end

        it "sets binx_response_rate_limited without calling Strava" do
          expect { instance.perform(strava_request.id) }.to change(StravaRequest, :count).by(1)

          strava_request.reload
          expect(strava_request.response_status).to eq("binx_response_rate_limited")
        end
      end

      context "when rate limits have sufficient remaining" do
        let!(:strava_activity) do
          FactoryBot.create(:strava_activity, strava_integration:, strava_id: "17323701543")
        end
        let!(:rate_limit_request) do
          FactoryBot.create(:strava_request, :processed, strava_integration:,
            requested_at: boundary + 1.second,
            rate_limit: {short_limit: 200, short_usage: 0, long_limit: 2000, long_usage: 0,
                         read_short_limit: 200, read_short_usage: 0, read_long_limit: 2000, read_long_usage: 0})
        end

        it "proceeds with the request" do
          VCR.use_cassette("strava-get_activity") do
            instance.perform(strava_request.id)
          end

          strava_request.reload
          expect(strava_request.response_status).to eq("success")
        end
      end
    end

    context "when currently_rate_limited?" do
      let(:boundary) { Time.current.change(min: (Time.current.min / 15) * 15, sec: 0) }
      let!(:rate_limit_request) do
        FactoryBot.create(:strava_request, :processed, strava_integration:,
          requested_at: boundary + 1.second,
          rate_limit: {short_limit: 200, short_usage: 0, long_limit: 2000, long_usage: 0,
                       read_short_limit: 200, read_short_usage: 198, read_long_limit: 2000, read_long_usage: 0})
      end

      it "sets binx_response_rate_limited and creates a retry request without calling Strava" do
        strava_request_id = strava_request.id

        expect { instance.perform(strava_request_id) }.to change(StravaRequest, :count).by(1)

        strava_request.reload
        expect(strava_request.response_status).to eq("binx_response_rate_limited")
        expect(strava_request.requested_at).to be_present
        expect(strava_request).to have_attributes(proxy_request: false,
          response_status: "binx_response_rate_limited")
        expect(strava_request.requested_at).to be_within(1).of Time.current

        retry_request = StravaRequest.last
        expect(retry_request.request_type).to eq(strava_request.request_type)
        expect(retry_request.requested_at).to be_nil
        expect(retry_request.response_status).to eq("pending")
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
      it "sets response_status to token_expired and re-enqueues" do
        strava_request_id = strava_request.id
        VCR.use_cassette("strava-unauthorized") do
          expect { instance.perform(strava_request_id) }.to change(StravaRequest, :count).by(1)
        end

        strava_request.reload
        expect(strava_request.requested_at).to be_present
        expect(strava_request.response_status).to eq("token_expired")

        retry_request = StravaRequest.last
        expect(retry_request.request_type).to eq(strava_request.request_type)
        expect(retry_request.strava_integration_id).to eq(strava_request.strava_integration_id)
        expect(retry_request.response_status).to eq("pending")
        expect(retry_request.requested_at).to be_nil
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
        expect(strava_request.parameters).to eq({error_response_status: 500}.as_json)
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
        expect(StravaRequest.pending.pluck(:id)).to eq([])
      end
    end

    context "with skippable request and sibling duplicates" do
      let!(:strava_activity) do
        FactoryBot.create(:strava_activity, strava_integration:, strava_id: "12345",
          enriched_at: 30.minutes.ago)
      end
      let!(:strava_request) { FactoryBot.create(:strava_request, :fetch_activity, strava_integration:) }
      let!(:sibling_request) { FactoryBot.create(:strava_request, :fetch_activity, strava_integration:) }
      let!(:different_activity_request) do
        FactoryBot.create(:strava_request, :fetch_activity, strava_integration:,
          parameters: {strava_id: "99999"})
      end

      it "skips the request and all pending siblings for the same activity" do
        instance.perform(strava_request.id)

        expect(strava_request.reload.response_status).to eq("skipped")
        expect(sibling_request.reload.response_status).to eq("skipped")
        expect(different_activity_request.reload.response_status).to eq("pending")
      end
    end

    context "when re-enqueued request has skippable sibling" do
      let!(:strava_activity) do
        FactoryBot.create(:strava_activity, strava_integration:, strava_id: "12345",
          enriched_at: 30.minutes.ago)
      end
      let!(:original_request) { FactoryBot.create(:strava_request, :fetch_activity, strava_integration:) }
      let!(:re_enqueued_request) { FactoryBot.create(:strava_request, :fetch_activity, strava_integration:) }

      it "skips the original request and siblings, not the re-enqueued request" do
        # Process the original (older) request first — it's skippable
        instance.perform(original_request.id)

        expect(original_request.reload.response_status).to eq("skipped")
        expect(re_enqueued_request.reload.response_status).to eq("skipped")

        # Create a new re-enqueued request (simulating what update_from_response does)
        new_request = StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :fetch_activity, parameters: {strava_id: "12345"})

        # The re-enqueued request is not skipped because siblings were already cleared
        expect(new_request.reload.response_status).to eq("pending")
      end
    end

    context "with proxy request that is rate limited" do
      let!(:strava_request) do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :fetch_activity, proxy_request: true,
          parameters: {url: "activities/12345"})
      end
      let(:boundary) { Time.current.change(min: (Time.current.min / 15) * 15, sec: 0) }
      let!(:rate_limit_request) do
        FactoryBot.create(:strava_request, :processed, strava_integration:,
          requested_at: boundary + 1.second,
          rate_limit: {short_limit: 200, short_usage: 0, long_limit: 2000, long_usage: 0,
                       read_short_limit: 200, read_short_usage: 198, read_long_limit: 2000, read_long_usage: 0})
      end

      it "does not re-enqueue proxy requests" do
        strava_request.update_from_response(:binx_response_rate_limited)

        expect(strava_request.reload.response_status).to eq("binx_response_rate_limited")
        expect(StravaRequest.pending.where(proxy_request: true).count).to eq(0)
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

    context "with request_type: incoming_webhook" do
      let!(:strava_request) do
        StravaRequest.create!(request_type: :incoming_webhook, user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id, parameters:)
      end
      let(:parameters) do
        {object_type: "activity", aspect_type:, updates:,
         object_id: "17323701543", owner_id: strava_integration.strava_id}
      end
      let(:aspect_type) { "create" }
      let(:updates) { {} }
      context "with incoming_webhook activity create" do
        it "creates or updates a StravaActivity" do
          expect(strava_integration.last_updated_activities_at).to be_nil
          expect { instance.perform(strava_request.id) }.to change(StravaActivity, :count).by(1)
            .and change(StravaRequest, :count).by 1

          strava_request.reload
          expect(strava_request.response_status).to eq("success")

          activity = strava_integration.strava_activities.find_by(strava_id: "17323701543")
          expect(activity).to be_present

          strava_integration.reload
          expect(strava_integration.last_updated_activities_at).to be_within(2).of(Time.current)
        end
      end

      context "with incoming_webhook activity update" do
        let!(:strava_activity) do
          FactoryBot.create(:strava_activity, strava_integration:, strava_id: "17323701543",
            title: "Morning Ride", distance_meters: 25000.0)
        end
        let(:aspect_type) { "update" }

        it "does not overwrite existing data" do
          expect { instance.perform(strava_request.id) }.to change(StravaRequest, :count).by(1)
            .and change(StravaActivity, :count).by(0)
            .and change(StravaJobs::RequestRunner.jobs, :count).by(0)

          strava_request.reload
          expect(strava_request.response_status).to eq("success")
          expect(strava_request.requested_at).to be_nil
          expect(strava_request.rate_limit).to be_nil

          strava_activity.reload
          expect(strava_activity.title).to eq("Morning Ride")
          expect(strava_activity.distance_meters).to eq(25000.0)

          new_strava_request = StravaRequest.last
          expect(new_strava_request.strava_integration_id).to eq strava_integration.id
          expect(new_strava_request.response_status).to eq "pending"
          expect(new_strava_request.request_type).to eq "fetch_activity"
        end

        context "with update data" do
          let(:updates) { {title: "New title", private: "false", visibility: "followers_only"} }
          it "Updates existing data" do
            expect { instance.perform(strava_request.id) }.to change(StravaRequest, :count).by(1)
              .and change(StravaActivity, :count).by(0)
              .and change(StravaJobs::RequestRunner.jobs, :count).by(0)

            strava_request.reload
            expect(strava_request.response_status).to eq("success")
            expect(strava_request.requested_at).to be_nil
            expect(strava_request.rate_limit).to be_nil

            strava_activity.reload
            expect(strava_activity.title).to eq("New title")
            expect(strava_activity.distance_meters).to eq(25000.0)
            expect(strava_activity.strava_data).to be_blank

            new_strava_request = StravaRequest.last
            expect(new_strava_request.strava_integration_id).to eq strava_integration.id
            expect(new_strava_request.response_status).to eq "pending"
            expect(new_strava_request.request_type).to eq "fetch_activity"
          end
        end
      end

      context "with incoming_webhook activity delete" do
        let!(:strava_activity) do
          FactoryBot.create(:strava_activity, strava_integration:, strava_id: "17323701543")
        end
        let(:aspect_type) { "delete" }

        it "destroys the StravaActivity" do
          expect { instance.perform(strava_request.id) }.to change(StravaActivity, :count).by(-1)

          strava_request.reload
          expect(strava_request.response_status).to eq("success")
          expect(strava_integration.strava_activities.find_by(strava_id: "17323701543")).to be_nil
        end
      end

      context "with incoming_webhook athlete" do
        let(:parameters) do
          {object_type: "athlete", aspect_type: "update",
           owner_id: strava_integration.strava_id, updates:}
        end
        it "creates a fetch_athlete request" do
          expect { instance.perform(strava_request.id) }.to change(StravaRequest, :count).by(1)

          strava_request.reload
          expect(strava_request.response_status).to eq("success")

          strava_request = StravaRequest.last
          expect(strava_request.request_type).to eq "fetch_athlete"
        end

        context "with deauth" do
          let(:updates) { {authorized: "false"} }
          it "soft-deletes the integration" do
            expect { instance.perform(strava_request.id) }.to change(StravaRequest, :count).by(0)

            strava_request.reload
            expect(strava_request.response_status).to eq("success")
            expect(StravaIntegration.find_by(id: strava_integration.id)).to be_nil
            expect(StravaIntegration.unscoped.find_by(id: strava_integration.id)).to be_present
          end
        end
      end
    end
  end
end
