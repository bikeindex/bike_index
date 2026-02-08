require "rails_helper"

RSpec.describe StravaIntegrationSyncNewActivitiesJob, type: :job do
  let(:instance) { described_class.new }

  it "is a ScheduledJob" do
    expect(described_class).to be < ScheduledJob
  end

  it "has the correct frequency" do
    expect(described_class.frequency).to eq(6.hours)
  end

  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
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
    let(:strava_integration) do
      FactoryBot.create(:strava_integration, :synced,
        access_token: "strava_access_token_xyz",
        refresh_token: "strava_test_refresh_token_456",
        token_expires_at: Time.current + 6.hours,
        athlete_id: "12345678")
    end
    let!(:existing_activity) do
      FactoryBot.create(:strava_activity,
        strava_integration: strava_integration,
        strava_id: "9876543",
        title: "Morning Ride",
        activity_type: "Ride",
        start_date: Time.parse("2025-06-15T08:00:00Z"))
    end

    before { allow(Integrations::Strava).to receive(:sleep) }

    it "syncs new activities for the integration" do
      VCR.use_cassette("strava-list_new_activities", match_requests_on: [:path]) do
        VCR.use_cassette("strava-get_activity_afternoon_ride", match_requests_on: [:path]) do
          expect {
            instance.perform(strava_integration.id)
          }.to change(StravaActivity, :count).by(1)
        end
      end
    end

    it "skips non-synced integrations" do
      strava_integration.update_column(:status, StravaIntegration.statuses[:pending])
      instance.perform(strava_integration.id)
      # No HTTP calls made, no error raised
    end

    it "does nothing when integration not found" do
      instance.perform(-1)
      # No error raised
    end
  end
end
