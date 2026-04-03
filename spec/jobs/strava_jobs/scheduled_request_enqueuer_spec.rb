# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaJobs::ScheduledRequestEnqueuer, type: :job do
  before { StravaRequest.destroy_all } # required because it's the analytics db
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  let(:instance) { described_class.new }

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
    expect(described_class.frequency).to eq(59.seconds)
  end

  describe "perform" do
    before { Sidekiq::Job.clear_all }
    it "does nothing when no pending requests" do
      instance.perform
      expect(described_class.jobs.size).to eq(3)
    end

    context "with pending requests" do
      let(:strava_integration) { FactoryBot.create(:strava_integration) }

      it "enqueues a job with the request id" do
        strava_request = StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id, request_type: :list_activities)
        instance.perform
        expect(StravaJobs::RequestRunner.jobs.size).to eq(1)
        expect(StravaJobs::RequestRunner.jobs.first["args"]).to eq([strava_request.id])
      end

      it "enqueues BATCH_SIZE requests" do
        stub_const("StravaJobs::ScheduledRequestEnqueuer::BATCH_SIZE", 5)

        5.times.map do |i|
          StravaRequest.create!(user_id: strava_integration.user_id,
            strava_integration_id: strava_integration.id, request_type: :fetch_activity,
            parameters: {strava_id: "1230000000#{i}"})
        end
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
        expect(StravaJobs::RequestRunner.jobs.size).to eq(5)
        expect(described_class.jobs.size).to eq(3)

        expect(StravaJobs::RequestRunner.jobs.map { |j| j["args"].first }[0..2])
          .to eq([list_activities.id, fetch_gear.id, fetch_activity.id])

        # Verify that it doesn't hang
        described_class.drain

        # Extra verification
        expect { instance.perform(true) }.to change(described_class.jobs, :count).by 0
      end

      describe "skip_duplicate_requests" do
        it "skips duplicate fetch_activity requests" do
          request1 = StravaRequest.create!(user_id: strava_integration.user_id,
            strava_integration_id: strava_integration.id, request_type: :fetch_activity,
            parameters: {strava_id: "111"})
          request2 = StravaRequest.create!(user_id: strava_integration.user_id,
            strava_integration_id: strava_integration.id, request_type: :fetch_activity,
            parameters: {strava_id: "111"})
          request3 = StravaRequest.create!(user_id: strava_integration.user_id,
            strava_integration_id: strava_integration.id, request_type: :fetch_activity,
            parameters: {strava_id: "222"})

          instance.perform

          expect(request1.reload.response_status).to eq("pending")
          expect(request2.reload.response_status).to eq("skipped")
          expect(request3.reload.response_status).to eq("pending")
        end

        it "skips duplicate fetch_gear requests" do
          request1 = StravaRequest.create!(user_id: strava_integration.user_id,
            strava_integration_id: strava_integration.id, request_type: :fetch_gear,
            parameters: {strava_gear_id: "b123"})
          request2 = StravaRequest.create!(user_id: strava_integration.user_id,
            strava_integration_id: strava_integration.id, request_type: :fetch_gear,
            parameters: {strava_gear_id: "b123"})

          instance.perform

          expect(request1.reload.response_status).to eq("pending")
          expect(request2.reload.response_status).to eq("skipped")
        end

        it "skips duplicate list_activities requests" do
          request1 = StravaRequest.create!(user_id: strava_integration.user_id,
            strava_integration_id: strava_integration.id, request_type: :list_activities,
            parameters: {page: 1})
          request2 = StravaRequest.create!(user_id: strava_integration.user_id,
            strava_integration_id: strava_integration.id, request_type: :list_activities,
            parameters: {page: 1})
          request3 = StravaRequest.create!(user_id: strava_integration.user_id,
            strava_integration_id: strava_integration.id, request_type: :list_activities,
            parameters: {page: 2})

          instance.perform

          expect(request1.reload.response_status).to eq("pending")
          expect(request2.reload.response_status).to eq("skipped")
          expect(request3.reload.response_status).to eq("pending")
        end

        context "with different integrations" do
          let(:strava_integration2) { FactoryBot.create(:strava_integration) }

          it "does not skip requests from different integrations" do
            request1 = StravaRequest.create!(user_id: strava_integration.user_id,
              strava_integration_id: strava_integration.id, request_type: :fetch_activity,
              parameters: {strava_id: "111"})
            request2 = StravaRequest.create!(user_id: strava_integration2.user_id,
              strava_integration_id: strava_integration2.id, request_type: :fetch_activity,
              parameters: {strava_id: "111"})

            instance.perform

            expect(request1.reload.response_status).to eq("pending")
            expect(request2.reload.response_status).to eq("pending")
          end
        end
      end

      describe "skip_enqueueing_fetch_activity_requests?" do
        let(:boundary) { Time.current.change(min: (Time.current.min / 15) * 15, sec: 0) }
        let(:read_short_usage) { 0 }
        let(:read_long_usage) { 0 }
        let!(:rate_limit_request) do
          FactoryBot.create(:strava_request, :processed, strava_integration:,
            requested_at: boundary + 1.second,
            rate_limit: {short_limit: 200, short_usage: 0, long_limit: 2000, long_usage: 0,
                         read_short_limit: 200, read_short_usage:, read_long_limit: 2000, read_long_usage:})
        end

        it "has expected constant values" do
          expect(described_class::ENQUEUER_FETCH_ACTIVITY_SHORT_HEADROOM).to eq(Integrations::Strava::Client::FETCH_ACTIVITY_SHORT_HEADROOM * 2)
          expect(described_class::ENQUEUER_FETCH_ACTIVITY_LONG_HEADROOM).to eq(Integrations::Strava::Client::FETCH_ACTIVITY_LONG_HEADROOM * 2)
        end

        context "when long remaining is below ENQUEUER_FETCH_ACTIVITY_LONG_HEADROOM" do
          let(:read_long_usage) { 1001 }

          it "is truthy" do
            expect(described_class.skip_enqueueing_fetch_activity_requests?).to be_truthy
          end
        end

        context "when long remaining is above ENQUEUER_FETCH_ACTIVITY_LONG_HEADROOM" do
          let(:read_long_usage) { 999 }

          it "is falsey" do
            expect(described_class.skip_enqueueing_fetch_activity_requests?).to be_falsey
          end
        end

        context "when short remaining is below ENQUEUER_FETCH_ACTIVITY_SHORT_HEADROOM" do
          let(:read_short_usage) { 1 }

          it "is truthy" do
            expect(described_class.skip_enqueueing_fetch_activity_requests?).to be_truthy
          end
        end

        context "when short remaining is above ENQUEUER_FETCH_ACTIVITY_SHORT_HEADROOM" do
          let(:read_short_usage) { 0 }

          it "is falsey" do
            expect(described_class.skip_enqueueing_fetch_activity_requests?).to be_falsey
          end
        end

        context "when skipping in perform" do
          let(:read_long_usage) { 1001 }

          it "excludes fetch_activity requests from batch but leaves them pending" do
            fetch_activity = StravaRequest.create!(user_id: strava_integration.user_id,
              strava_integration_id: strava_integration.id, request_type: :fetch_activity,
              parameters: {strava_id: "123"})
            list_activities = StravaRequest.create!(user_id: strava_integration.user_id,
              strava_integration_id: strava_integration.id, request_type: :list_activities,
              parameters: {page: 1})

            instance.perform

            expect(fetch_activity.reload.response_status).to eq("pending")
            expect(list_activities.reload.response_status).to eq("pending")
            expect(StravaJobs::RequestRunner.jobs.size).to eq(1)
            expect(StravaJobs::RequestRunner.jobs.first["args"]).to eq([list_activities.id])
          end
        end
      end

      context "when more than 10 requests enqueued" do
        it "skips enqueue" do
          StravaRequest.create!(user_id: strava_integration.user_id,
            strava_integration_id: strava_integration.id, request_type: :list_activities)
          allow(instance).to receive(:enqueued_runner_count).and_return(11)

          instance.perform
          expect(StravaJobs::RequestRunner.jobs.size).to eq(0)
        end
      end

      context "when rate limited" do
        let(:boundary) { Time.current.change(min: (Time.current.min / 15) * 15, sec: 0) }
        let(:rate_limit) do
          {short_limit: 100, short_usage: 0, long_limit: 1000, long_usage: 200,
           read_short_limit: 100, read_short_usage: 95, read_long_limit: 1000, read_long_usage: 200}
        end
        let!(:rate_limit_request) do
          FactoryBot.create(:strava_request, :processed, strava_integration:,
            requested_at: boundary + 1.second, rate_limit:)
        end

        it "skips enqueue when read short rate limit headroom is insufficient" do
          instance.perform
          expect(StravaJobs::RequestRunner.jobs.size).to eq(0)
          expect(described_class.jobs.size).to eq(0)
        end

        context "long read limit" do
          let(:rate_limit) do
            {short_limit: 200, short_usage: 0, long_limit: 1000, long_usage: 0,
             read_short_limit: 200, read_short_usage: 0, read_long_limit: 1000, read_long_usage: 995}
          end
          it "skips enqueue when read long rate limit headroom is insufficient" do
            instance.perform
            expect(StravaJobs::RequestRunner.jobs.size).to eq(0)
            expect(described_class.jobs.size).to eq(0)
          end
        end
      end
    end
  end
end
