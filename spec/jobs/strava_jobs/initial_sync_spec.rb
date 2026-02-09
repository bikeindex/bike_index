require "rails_helper"

RSpec.describe StravaJobs::InitialSync, type: :job do
  let(:instance) { described_class.new }

  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
  end

  describe "perform" do
    let(:strava_integration) do
      FactoryBot.create(:strava_integration,
        athlete_id: ENV["STRAVA_TEST_USER_ID"])
    end

    it "creates a fetch_athlete request and runs it inline" do
      VCR.use_cassette("strava-get_athlete") do
        instance.perform(strava_integration.id)
      end

      request = StravaRequest.where(request_type: :fetch_athlete).first
      expect(request.requested_at).to be_present
      expect(request.response_status).to eq("success")
      expect(request.strava_integration_id).to eq(strava_integration.id)

      follow_up = StravaRequest.where(request_type: :fetch_athlete_stats).first
      expect(follow_up).to be_present
    end

    it "does nothing when integration not found" do
      expect {
        instance.perform(-1)
      }.not_to change(StravaRequest, :count)
    end
  end
end
