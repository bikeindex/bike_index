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

        5.times.map do
          StravaRequest.create!(user_id: strava_integration.user_id,
            strava_integration_id: strava_integration.id, request_type: :fetch_activity,
            parameters: {strava_id: "12300000000"})
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

      context "when rate limited" do
        let(:strava_request) do
          StravaRequest.create!(user_id: strava_integration.user_id,
            strava_integration_id: strava_integration.id, request_type: :list_activities)
        end
        let(:limit_hash) do
          {"read_short_limit" => 100, "read_short_usage" => 95, "read_long_limit" => 1000, "read_long_usage" => 200}
        end

        before { allow(StravaRequest).to receive(:estimated_current_rate_limit).and_return(limit_hash) }

        it "skips enqueue when read short rate limit headroom is insufficient" do
          instance.perform
          expect(StravaJobs::RequestRunner.jobs.size).to eq(0)
          expect(described_class.jobs.size).to eq(0)
        end

        context "long read limit" do
          let(:limit_hash) do
            {"read_short_limit" => 200, "read_short_usage" => 0, "read_long_limit" => 1000, "read_long_usage" => 995}
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
