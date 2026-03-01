# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaJobs::ScheduledRequestPriorityUpdator, type: :job do
  before { StravaRequest.destroy_all }
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  let(:instance) { described_class.new }

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
    expect(described_class.frequency).to eq(50.minutes)
  end

  describe "perform with no args" do
    let(:strava_integration) { FactoryBot.create(:strava_integration) }

    it "does nothing when no pending requests" do
      instance.perform
      expect(described_class.jobs.size).to eq(0)
    end

    context "with multiple integrations" do
      let(:strava_integration2) { FactoryBot.create(:strava_integration) }
      let!(:request1) { FactoryBot.create(:strava_request, :fetch_activity, strava_integration:) }
      let!(:request2) { FactoryBot.create(:strava_request, :fetch_activity, strava_integration: strava_integration2) }

      it "enqueues each integration independently" do
        instance.perform
        expect(described_class.jobs.size).to eq(2)
        enqueued_args = described_class.jobs.map { |j| j["args"].first }
        expect(enqueued_args).to match_array([strava_integration.id, strava_integration2.id])
      end
    end
  end

  describe "perform with strava_integration_id" do
    let(:strava_integration) { FactoryBot.create(:strava_integration) }
    let!(:request) { FactoryBot.create(:strava_request, :fetch_activity, strava_integration:) }
    let(:proxy_requested_at) { nil }
    let!(:strava_request_proxy) do
      proxy_requested_at && FactoryBot.create(:strava_request, :proxy, :processed, strava_integration:, requested_at: proxy_requested_at)
    end

    context "with no proxy requests" do
      it "multiplies priority by 4" do
        original_priority = request.priority
        instance.perform(strava_integration.id)
        expect(request.reload.priority).to eq((original_priority * 4).to_i)
      end
    end

    context "with proxy request less than 1 hour ago" do
      let(:proxy_requested_at) { 30.minutes.ago }

      it "divides priority by 4" do
        original_priority = request.priority
        instance.perform(strava_integration.id)
        expect(request.reload.priority).to eq((original_priority * 0.25).to_i)
      end
    end

    context "with proxy request less than 24 hours ago" do
      let(:proxy_requested_at) { 6.hours.ago }

      it "divides priority by 2" do
        original_priority = request.priority
        instance.perform(strava_integration.id)
        expect(request.reload.priority).to eq((original_priority * 0.5).to_i)
      end
    end

    context "with proxy request more than 1 week ago" do
      let(:proxy_requested_at) { 2.weeks.ago }

      it "multiplies priority by 4" do
        original_priority = request.priority
        instance.perform(strava_integration.id)
        expect(request.reload.priority).to eq((original_priority * 4).to_i)
      end
    end

    context "with proxy request between 1 day and 1 week ago" do
      let(:proxy_requested_at) { 3.days.ago }

      it "does not change priorities" do
        original_priority = request.priority
        instance.perform(strava_integration.id)
        expect(request.reload.priority).to eq(original_priority)
      end
    end
  end
end
