# frozen_string_literal: true

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

    it "fetches athlete, stats, and list pages inline, then creates activities" do
      VCR.use_cassette("strava-get_athlete") do
        VCR.use_cassette("strava-get_athlete_stats") do
          VCR.use_cassette("strava-list_activities", allow_playback_repeats: true) do
            instance.perform(strava_integration.id)
          end
        end
      end

      strava_integration.reload
      expect(strava_integration.athlete_activity_count).to eq(1817)

      requests = StravaRequest.where(strava_integration_id: strava_integration.id).order(:created_at)
      athlete_request = requests.find_by(request_type: :fetch_athlete)
      expect(athlete_request.response_status).to eq("success")
      expect(athlete_request.requested_at).to be_present

      stats_request = requests.find_by(request_type: :fetch_athlete_stats)
      expect(stats_request.response_status).to eq("success")
      expect(stats_request.requested_at).to be_present

      list_requests = requests.where(request_type: :list_activities).order(:id)
      # 1817 activities / 200 per page = 10 pages, all fetched inline
      expect(list_requests.count).to eq(10)
      expect(list_requests.first.parameters["page"]).to eq(1)
      expect(list_requests.last.parameters["page"]).to eq(10)
      expect(list_requests.pluck(:requested_at).compact.count).to eq(10)

      expect(strava_integration.strava_activities.count).to be > 0
      # Status is synced because all list pages completed and update_sync_status ran
      expect(strava_integration.status).to eq("synced")
    end

    it "does nothing when integration not found" do
      expect {
        instance.perform(-1)
      }.not_to change(StravaRequest, :count)
    end
  end
end
