require "rails_helper"

RSpec.describe StravaIntegrationSyncNewActivitiesJob, type: :job do
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

    it "enqueues page sync job with after_epoch" do
      instance.perform(strava_integration.id)
      expect(StravaActivityPageSyncJob.jobs.size).to eq(1)
      job_args = StravaActivityPageSyncJob.jobs.first["args"]
      expect(job_args[0]).to eq(strava_integration.id)
      expect(job_args[1]).to eq(1)
      expect(job_args[2]).to eq(existing_activity.start_date.to_i)
    end

    it "skips non-synced integrations" do
      strava_integration.update_column(:status, StravaIntegration.statuses[:pending])
      instance.perform(strava_integration.id)
      expect(StravaActivityPageSyncJob.jobs.size).to eq(0)
    end

    it "does nothing when integration not found" do
      instance.perform(-1)
      expect(StravaActivityPageSyncJob.jobs.size).to eq(0)
    end
  end
end
