require "rails_helper"

RSpec.describe StravaIntegrationSyncJob, type: :job do
  let(:instance) { described_class.new }

  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
  end

  describe "perform" do
    let(:strava_integration) do
      FactoryBot.create(:strava_integration,
        token_expires_at: Time.current + 6.hours,
        athlete_id: ENV["STRAVA_TEST_USER_ID"])
    end

    it "creates a fetch_athlete request and enqueues the runner" do
      expect {
        instance.perform(strava_integration.id)
      }.to change(StravaRequest, :count).by(1)

      request = StravaRequest.last
      expect(request.request_type).to eq("fetch_athlete")
      expect(request.endpoint).to eq("athlete")
      expect(request.strava_integration_id).to eq(strava_integration.id)
      expect(request.user_id).to eq(strava_integration.user_id)
      expect(StravaRequestRunnerJob.jobs.size).to eq(1)
    end

    it "does nothing when integration not found" do
      expect {
        instance.perform(-1)
      }.not_to change(StravaRequest, :count)
      expect(StravaRequestRunnerJob.jobs.size).to eq(0)
    end
  end
end
