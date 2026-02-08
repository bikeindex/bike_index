require "rails_helper"

RSpec.describe StravaRequestRunnerJob, type: :job do
  let(:instance) { described_class.new }

  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
  end

  describe "perform" do
    it "does nothing when no pending requests" do
      instance.perform
    end

    context "with fetch_athlete request" do
      let(:strava_integration) do
        FactoryBot.create(:strava_integration,
          token_expires_at: Time.current + 6.hours,
          athlete_id: ENV["STRAVA_TEST_USER_ID"])
      end
      let!(:request) do
        StravaRequest.create!(
          user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :fetch_athlete,
          endpoint: "athlete"
        )
      end

      it "calls fetch_athlete and creates fetch_athlete_stats follow-up" do
        VCR.use_cassette("strava-get_athlete") do
          instance.perform
        end

        request.reload
        expect(request.requested_at).to be_present
        expect(request.response_status).to eq("success")

        follow_up = StravaRequest.where(strava_integration_id: strava_integration.id, request_type: :fetch_athlete_stats).first
        expect(follow_up).to be_present
        expect(follow_up.parameters["athlete_id"]).to eq("2430215")
        expect(described_class.jobs.size).to eq(1)
      end
    end

    context "with fetch_athlete_stats request" do
      let(:strava_integration) do
        FactoryBot.create(:strava_integration,
          token_expires_at: Time.current + 6.hours,
          athlete_id: ENV["STRAVA_TEST_USER_ID"])
      end
      let!(:request) do
        StravaRequest.create!(
          user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :fetch_athlete_stats,
          endpoint: "athletes/#{ENV["STRAVA_TEST_USER_ID"]}/stats",
          parameters: {athlete_id: ENV["STRAVA_TEST_USER_ID"], athlete_data: {"id" => ENV["STRAVA_TEST_USER_ID"]}}
        )
      end

      it "updates integration and creates list_activities follow-up" do
        VCR.use_cassette("strava-get_athlete_stats") do
          instance.perform
        end

        request.reload
        expect(request.response_status).to eq("success")

        strava_integration.reload
        expect(strava_integration.status).to eq("syncing")
        expect(strava_integration.athlete_activity_count).to eq(1817)

        follow_up = StravaRequest.where(strava_integration_id: strava_integration.id, request_type: :list_activities).first
        expect(follow_up).to be_present
        expect(follow_up.parameters["page"]).to eq(1)
      end
    end

    context "with list_activities request" do
      let(:strava_integration) do
        FactoryBot.create(:strava_integration, :syncing,
          token_expires_at: Time.current + 6.hours,
          athlete_id: ENV["STRAVA_TEST_USER_ID"])
      end
      let!(:request) do
        StravaRequest.create!(
          user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :list_activities,
          endpoint: "athlete/activities",
          parameters: {page: 1, per_page: 200}
        )
      end

      it "creates activities and enqueues detail requests for cycling activities" do
        VCR.use_cassette("strava-list_activities") do
          instance.perform
        end

        request.reload
        expect(request.response_status).to eq("success")
        expect(strava_integration.strava_activities.count).to be > 0

        cycling_count = strava_integration.strava_activities.cycling.count
        detail_requests = StravaRequest.where(strava_integration_id: strava_integration.id, request_type: :fetch_activity)
        expect(detail_requests.count).to eq(cycling_count)
      end
    end

    context "with fetch_activity request" do
      let(:strava_integration) do
        FactoryBot.create(:strava_integration, :syncing,
          token_expires_at: Time.current + 6.hours,
          athlete_id: ENV["STRAVA_TEST_USER_ID"])
      end
      let!(:activity) do
        FactoryBot.create(:strava_activity,
          strava_integration:,
          strava_id: "17323701543")
      end
      let!(:request) do
        StravaRequest.create!(
          user_id: strava_integration.user_id,
          strava_integration_id: strava_integration.id,
          request_type: :fetch_activity,
          endpoint: "activities/#{activity.strava_id}",
          parameters: {strava_id: activity.strava_id, strava_activity_id: activity.id}
        )
      end

      it "updates activity details and finishes sync when last" do
        VCR.use_cassette("strava-get_activity") do
          instance.perform
        end

        request.reload
        expect(request.response_status).to eq("success")
        strava_integration.reload
        expect(strava_integration.status).to eq("synced")
      end
    end

    context "with missing strava_integration" do
      let!(:request) do
        StravaRequest.create!(
          user_id: 1,
          strava_integration_id: -1,
          request_type: :fetch_athlete,
          endpoint: "athlete"
        )
      end

      it "marks request as error" do
        instance.perform

        request.reload
        expect(request.requested_at).to be_present
        expect(request.response_status).to eq("error")
      end
    end
  end
end
