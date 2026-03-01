# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaJobs::ScheduledRequestPriorityUpdator, type: :job do
  before { StravaRequest.destroy_all }
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  let(:instance) { described_class.new }

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
    expect(described_class.frequency).to eq(1.hour)
  end

  describe "perform" do
    let(:strava_integration) { FactoryBot.create(:strava_integration) }

    it "does nothing when no pending requests" do
      instance.perform
    end

    context "with pending requests and no proxy requests" do
      it "does not change priorities" do
        request = StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :fetch_activity, parameters: {strava_id: "123"})
        original_priority = request.priority

        instance.perform
        expect(request.reload.priority).to eq(original_priority)
      end
    end

    context "with proxy request less than 1 hour ago" do
      it "divides priority by 4" do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :proxy, parameters: {url: "/athlete"},
          requested_at: 30.minutes.ago, response_status: :success)

        request = StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :fetch_activity, parameters: {strava_id: "123"})
        original_priority = request.priority

        instance.perform
        expect(request.reload.priority).to eq((original_priority * 0.25).to_i)
      end
    end

    context "with proxy request less than 24 hours ago" do
      it "divides priority by 2" do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :proxy, parameters: {url: "/athlete"},
          requested_at: 6.hours.ago, response_status: :success)

        request = StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :fetch_activity, parameters: {strava_id: "123"})
        original_priority = request.priority

        instance.perform
        expect(request.reload.priority).to eq((original_priority * 0.5).to_i)
      end
    end

    context "with proxy request more than 1 week ago" do
      it "multiplies priority by 4" do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :proxy, parameters: {url: "/athlete"},
          requested_at: 2.weeks.ago, response_status: :success)

        request = StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :fetch_activity, parameters: {strava_id: "123"})
        original_priority = request.priority

        instance.perform
        expect(request.reload.priority).to eq((original_priority * 4).to_i)
      end
    end

    context "with proxy request between 1 day and 1 week ago" do
      it "does not change priorities" do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :proxy, parameters: {url: "/athlete"},
          requested_at: 3.days.ago, response_status: :success)

        request = StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :fetch_activity, parameters: {strava_id: "123"})
        original_priority = request.priority

        instance.perform
        expect(request.reload.priority).to eq(original_priority)
      end
    end

    context "with multiple integrations" do
      let(:strava_integration2) { FactoryBot.create(:strava_integration) }

      it "updates priorities for each integration independently" do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :proxy, parameters: {url: "/athlete"},
          requested_at: 30.minutes.ago, response_status: :success)

        request1 = StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :fetch_activity, parameters: {strava_id: "1"})
        request2 = StravaRequest.create!(user_id: strava_integration2.user_id,
          strava_integration_id: strava_integration2.id,
          request_type: :fetch_activity, parameters: {strava_id: "2"})

        original_priority1 = request1.priority
        original_priority2 = request2.priority

        instance.perform

        # Integration 1 has recent proxy - priority divided by 4
        expect(request1.reload.priority).to eq((original_priority1 * 0.25).to_i)
        # Integration 2 has no proxy - priority unchanged
        expect(request2.reload.priority).to eq(original_priority2)
      end
    end
  end
end
