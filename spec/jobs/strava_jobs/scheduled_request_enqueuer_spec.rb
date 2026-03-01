# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaJobs::ScheduledRequestEnqueuer, type: :job do
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
      expect(StravaJobs::RequestRunner.jobs.size).to eq(0)
    end

    context "with pending requests and no proxy requests" do
      it "enqueues up to BULK_ENQUEUE_SIZE requests" do
        3.times do
          StravaRequest.create!(user_id: strava_integration.user_id,
            strava_integration_id: strava_integration.id,
            request_type: :fetch_activity, parameters: {strava_id: "123"})
        end

        instance.perform
        expect(StravaJobs::RequestRunner.jobs.size).to eq(3)
      end
    end

    context "with proxy request less than 1 hour ago" do
      it "enqueues batch_size / 4 requests" do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :proxy, parameters: {url: "/athlete"},
          requested_at: 30.minutes.ago, response_status: :success)

        50.times do |i|
          StravaRequest.create!(user_id: strava_integration.user_id,
            strava_integration_id: strava_integration.id,
            request_type: :fetch_activity, parameters: {strava_id: i.to_s})
        end

        instance.perform
        expect(StravaJobs::RequestRunner.jobs.size).to eq(Integrations::StravaClient::BULK_ENQUEUE_SIZE / 4)
      end
    end

    context "with proxy request less than 24 hours ago" do
      it "enqueues batch_size / 2 requests" do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :proxy, parameters: {url: "/athlete"},
          requested_at: 6.hours.ago, response_status: :success)

        50.times do |i|
          StravaRequest.create!(user_id: strava_integration.user_id,
            strava_integration_id: strava_integration.id,
            request_type: :fetch_activity, parameters: {strava_id: i.to_s})
        end

        instance.perform
        expect(StravaJobs::RequestRunner.jobs.size).to eq(Integrations::StravaClient::BULK_ENQUEUE_SIZE / 2)
      end
    end

    context "with proxy request more than 1 week ago" do
      it "enqueues batch_size * 4 requests" do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :proxy, parameters: {url: "/athlete"},
          requested_at: 2.weeks.ago, response_status: :success)

        200.times do |i|
          StravaRequest.create!(user_id: strava_integration.user_id,
            strava_integration_id: strava_integration.id,
            request_type: :fetch_activity, parameters: {strava_id: i.to_s})
        end

        instance.perform
        expect(StravaJobs::RequestRunner.jobs.size).to eq(Integrations::StravaClient::BULK_ENQUEUE_SIZE * 4)
      end
    end

    context "with multiple integrations" do
      let(:strava_integration2) { FactoryBot.create(:strava_integration) }

      it "enqueues requests for each integration independently" do
        StravaRequest.create!(user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :fetch_activity, parameters: {strava_id: "1"})
        StravaRequest.create!(user_id: strava_integration2.user_id,
          strava_integration_id: strava_integration2.id,
          request_type: :fetch_activity, parameters: {strava_id: "2"})

        instance.perform
        expect(StravaJobs::RequestRunner.jobs.size).to eq(2)
      end
    end
  end
end
