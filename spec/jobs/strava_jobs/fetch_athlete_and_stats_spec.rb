require "rails_helper"

RSpec.describe StravaJobs::FetchAthleteAndStats, type: :job do
  let(:instance) { described_class.new }

  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
  end

  describe "perform" do
    let(:strava_integration) do
      FactoryBot.create(:strava_integration,
        athlete_id: ENV["STRAVA_TEST_USER_ID"])
    end

    it "fetches athlete and stats, updates integration, and creates list_activities follow-up" do
      VCR.use_cassette("strava-get_athlete") do
        VCR.use_cassette("strava-get_athlete_stats") do
          instance.perform(strava_integration.id)
        end
      end

      strava_integration.reload
      expect(strava_integration.status).to eq("syncing")
      expect(strava_integration.athlete_activity_count).to eq(1817)

      requests = StravaRequest.where(strava_integration_id: strava_integration.id).order(:created_at)
      athlete_request = requests.find_by(request_type: :fetch_athlete)
      expect(athlete_request.endpoint).to eq("athlete")
      expect(athlete_request.response_status).to eq("success")
      expect(athlete_request.requested_at).to be_present

      stats_request = requests.find_by(request_type: :fetch_athlete_stats)
      expect(stats_request.endpoint).to start_with("athletes/")
      expect(stats_request.response_status).to eq("success")
      expect(stats_request.requested_at).to be_present

      follow_up = requests.find_by(request_type: :list_activities)
      expect(follow_up).to be_present
      expect(follow_up.parameters["per_page"]).to eq(200)
    end

    it "does nothing when integration not found" do
      expect {
        instance.perform(-1)
      }.not_to change(StravaRequest, :count)
    end
  end
end
