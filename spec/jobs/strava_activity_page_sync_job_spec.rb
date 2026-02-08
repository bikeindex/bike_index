require "rails_helper"

RSpec.describe StravaActivityPageSyncJob, type: :job do
  let(:instance) { described_class.new }
  let(:strava_integration) do
    FactoryBot.create(:strava_integration,
      access_token: "strava_access_token_xyz",
      refresh_token: "strava_test_refresh_token_456",
      token_expires_at: Time.current + 6.hours,
      athlete_id: "12345678")
  end

  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
  end

  describe "perform" do
    it "saves activities from the page" do
      VCR.use_cassette("strava-list_activities", match_requests_on: [:path]) do
        expect {
          instance.perform(strava_integration.id, 1)
        }.to change(StravaActivity, :count).by(3)
      end
    end

    it "updates activities_downloaded_count" do
      VCR.use_cassette("strava-list_activities", match_requests_on: [:path]) do
        instance.perform(strava_integration.id, 1)
        expect(strava_integration.reload.activities_downloaded_count).to eq(3)
      end
    end

    it "enqueues detail jobs for cycling activities and marks last as synced" do
      VCR.use_cassette("strava-list_activities", match_requests_on: [:path]) do
        instance.perform(strava_integration.id, 1)
        # 2 cycling activities (Morning Ride + Zwift Session), detail jobs enqueued
        expect(StravaActivityDetailSyncJob.jobs.size).to eq(2)
        # Last job should have mark_synced=true
        expect(StravaActivityDetailSyncJob.jobs.last["args"].last).to eq(true)
      end
    end

    it "finishes sync when no cycling activities need details" do
      VCR.use_cassette("strava-list_activities", match_requests_on: [:path]) do
        # Stub to return only the run activity
        allow(Integrations::Strava).to receive(:list_activities).and_return(
          [{"id" => 9876544, "name" => "Evening Run", "distance" => 5000.0,
            "moving_time" => 1800, "total_elevation_gain" => 50.0,
            "sport_type" => "Run", "type" => "Run",
            "start_date" => "2025-06-14T18:00:00Z", "start_latlng" => nil,
            "private" => false, "kudos_count" => 3}]
        )
        instance.perform(strava_integration.id, 1)
        expect(strava_integration.reload.status).to eq("synced")
        expect(StravaActivityDetailSyncJob.jobs.size).to eq(0)
      end
    end

    it "does nothing when integration not found" do
      instance.perform(-1, 1)
      expect(StravaActivity.count).to eq(0)
    end

    context "with after_epoch (incremental sync)" do
      let!(:existing_activity) do
        FactoryBot.create(:strava_activity,
          strava_integration:,
          strava_id: "9876543",
          activity_type: "Ride",
          start_date: Time.parse("2025-06-15T08:00:00Z"))
      end

      it "enqueues detail jobs only for new cycling activities after the epoch" do
        VCR.use_cassette("strava-list_new_activities", match_requests_on: [:path]) do
          after_epoch = existing_activity.start_date.to_i
          instance.perform(strava_integration.id, 1, after_epoch)

          # Only the new cycling activity (Afternoon Ride, after existing start_date)
          expect(StravaActivityDetailSyncJob.jobs.size).to eq(1)
        end
      end
    end
  end
end
