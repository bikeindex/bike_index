require "rails_helper"

RSpec.describe StravaJobs::SyncNewActivities, type: :job do
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  let(:instance) { described_class.new }

  it "has the correct frequency" do
    expect(described_class.frequency).to eq(6.hours)
  end

  describe "perform with no args (enqueue_workers)" do
    let!(:synced_integration) { FactoryBot.create(:strava_integration, :synced) }
    let!(:pending_integration) { FactoryBot.create(:strava_integration) }
    let!(:error_integration) { FactoryBot.create(:strava_integration, :error) }

    it "enqueues jobs only for synced integrations" do
      expect {
        instance.perform
      }.to change(described_class.jobs, :size).by(1)
    end
  end

  describe "perform with strava_integration_id" do
    let(:strava_integration) { FactoryBot.create(:strava_integration, :synced) }
    let!(:existing_activity) do
      FactoryBot.create(:strava_activity,
        strava_integration:,
        strava_id: "9876543",
        start_date: Time.parse("2025-06-15T08:00:00Z"))
    end

    it "creates a list_activities request and runs it inline" do
      VCR.use_cassette("strava-list_activities") do
        instance.perform(strava_integration.id)
      end

      request = StravaRequest.where(request_type: :list_activities).first
      expect(request.requested_at).to be_present
      expect(request.response_status).to eq("success")
      expect(request.parameters["per_page"]).to eq(200)
      expect(request.parameters["after"]).to eq(existing_activity.start_date.to_i)
    end

    it "skips non-synced integrations" do
      strava_integration.update_column(:status, StravaIntegration.statuses[:pending])
      expect {
        instance.perform(strava_integration.id)
      }.not_to change(StravaRequest, :count)
    end

    it "does nothing when integration not found" do
      expect {
        instance.perform(-1)
      }.not_to change(StravaRequest, :count)
    end
  end
end
