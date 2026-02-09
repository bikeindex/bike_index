require "rails_helper"

RSpec.describe StravaJobs::RequestRunner, type: :job do
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

    context "with a pending request" do
      let(:strava_integration) { FactoryBot.create(:strava_integration) }
      let!(:request) do
        StravaRequest.create!(
          user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :list_activities,
          endpoint: "athlete/activities",
          parameters: {per_page: 200}
        )
      end

      it "enqueues a job with the request id" do
        instance.perform
        expect(described_class.jobs.size).to eq(1)
        expect(described_class.jobs.first["args"]).to eq([request.id])
      end
    end
  end

  describe "perform with strava_request_id" do
    context "with list_activities request" do
      let(:strava_integration) do
        FactoryBot.create(:strava_integration, :syncing,
          athlete_id: ENV["STRAVA_TEST_USER_ID"])
      end
      let!(:request) do
        StravaRequest.create!(
          user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :list_activities,
          endpoint: "athlete/activities",
          parameters: {per_page: 200}
        )
      end

      it "creates activities and enqueues detail requests for cycling activities" do
        VCR.use_cassette("strava-list_activities") do
          instance.perform(request.id)
        end

        request.reload
        expect(request.response_status).to eq("success")
        expect(strava_integration.strava_activities.count).to be > 0

        cycling_count = strava_integration.strava_activities.cycling.count
        detail_requests = StravaRequest.where(strava_integration_id: strava_integration.id, request_type: :fetch_activity)
        expect(detail_requests.count).to eq(cycling_count)
      end
    end

    context "with fetch_activity request" do
      let(:strava_integration) do
        FactoryBot.create(:strava_integration, :syncing,
          athlete_id: ENV["STRAVA_TEST_USER_ID"])
      end
      let!(:activity) do
        FactoryBot.create(:strava_activity,
          strava_integration:,
          strava_id: "17323701543")
      end
      let!(:request) do
        StravaRequest.create!(
          user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :fetch_activity,
          endpoint: "activities/#{activity.strava_id}",
          parameters: {strava_id: activity.strava_id, strava_activity_id: activity.id}
        )
      end

      it "updates activity details and finishes sync when last" do
        VCR.use_cassette("strava-get_activity") do
          instance.perform(request.id)
        end

        request.reload
        expect(request.response_status).to eq("success")
        strava_integration.reload
        expect(strava_integration.status).to eq("synced")
      end
    end

    context "with rate limited response" do
      let(:strava_integration) do
        FactoryBot.create(:strava_integration, :syncing,
          athlete_id: ENV["STRAVA_TEST_USER_ID"])
      end
      let!(:request) do
        StravaRequest.create!(
          user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :list_activities,
          endpoint: "athlete/activities",
          parameters: {per_page: 200}
        )
      end

      it "sets response_status to rate_limited and creates a retry request" do
        VCR.use_cassette("strava-rate_limited") do
          expect { instance.perform(request.id) }.to change(StravaRequest, :count).by(1)
        end

        request.reload
        expect(request.requested_at).to be_present
        expect(request.response_status).to eq("rate_limited")
        expect(request.rate_limit).to eq({"short_limit" => 100, "short_usage" => 101, "long_limit" => 1000, "long_usage" => 350,
          "read_short_limit" => 100, "read_short_usage" => 101, "read_long_limit" => 1000, "read_long_usage" => 350})

        retry_request = StravaRequest.last
        expect(retry_request.request_type).to eq(request.request_type)
        expect(retry_request.endpoint).to eq(request.endpoint)
        expect(retry_request.requested_at).to be_nil
      end
    end

    context "with unauthorized response" do
      let(:strava_integration) do
        FactoryBot.create(:strava_integration, :syncing,
          athlete_id: ENV["STRAVA_TEST_USER_ID"])
      end
      let!(:request) do
        StravaRequest.create!(
          user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :list_activities,
          endpoint: "athlete/activities",
          parameters: {per_page: 200}
        )
      end

      it "sets response_status to token_refresh_failed" do
        VCR.use_cassette("strava-unauthorized") do
          instance.perform(request.id)
        end

        request.reload
        expect(request.requested_at).to be_present
        expect(request.response_status).to eq("token_refresh_failed")
      end
    end

    context "with server error response" do
      let(:strava_integration) do
        FactoryBot.create(:strava_integration, :syncing,
          athlete_id: ENV["STRAVA_TEST_USER_ID"])
      end
      let!(:request) do
        StravaRequest.create!(
          user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :list_activities,
          endpoint: "athlete/activities",
          parameters: {per_page: 200}
        )
      end

      it "raises and sets response_status to error" do
        VCR.use_cassette("strava-server_error") do
          expect { instance.perform(request.id) }.to raise_error(/Strava API error 500/)
        end

        request.reload
        expect(request.requested_at).to be_present
        expect(request.response_status).to eq("error")
      end
    end

    context "with missing strava_integration" do
      let!(:request) do
        StravaRequest.create!(
          user_id: 1,
          strava_integration_id: -1,
          request_type: :list_activities,
          endpoint: "athlete/activities",
          parameters: {per_page: 200}
        )
      end

      it "marks request as error" do
        instance.perform(request.id)

        request.reload
        expect(request.requested_at).to be_present
        expect(request.response_status).to eq("error")
      end
    end

    context "with already processed request" do
      let(:strava_integration) { FactoryBot.create(:strava_integration) }
      let!(:request) do
        StravaRequest.create!(
          user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :list_activities,
          endpoint: "athlete/activities",
          parameters: {per_page: 200},
          requested_at: Time.current,
          response_status: :success
        )
      end

      it "skips the request" do
        instance.perform(request.id)
      end
    end
  end
end
