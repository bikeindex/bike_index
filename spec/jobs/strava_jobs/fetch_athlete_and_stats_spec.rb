# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaJobs::FetchAthleteAndStats, type: :job do
  let(:instance) { described_class.new }

  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
  end

  describe "perform" do
    let(:strava_integration) do
      FactoryBot.create(:strava_integration, athlete_id: ENV["STRAVA_TEST_USER_ID"])
    end
    let(:target_strava_data) do
      {
        bio: "", sex: "M", city: "San Francisco", state: "California", friend: nil, summit: true, weight: 72.5747,
        country: "United States", premium: true, follower: nil,
        profile: "https://dgalywyr863hv.cloudfront.net/pictures/athletes/2430215/2807433/6/large.jpg",
        profile_medium: "https://dgalywyr863hv.cloudfront.net/pictures/athletes/2430215/2807433/6/medium.jpg",
        lastname: "herr", username: "sethherr", firstname: "seth", created_at: "2013-06-26T20:41:15Z",
        updated_at: "2026-02-02T18:05:52Z", badge_type_id: 1, resource_state: 2
      }
    end
    let(:target_proxy_response) { target_strava_data.merge(id: strava_integration.athlete_id, bikes:, shoes:) }
    let(:bikes) { [] }
    let(:shoes) { [] }

    it "fetches athlete and stats, updates integration, and creates list_activities follow-up" do
      VCR.use_cassette("strava-get_athlete") do
        VCR.use_cassette("strava-get_athlete_stats") do
          expect do
            instance.perform(strava_integration.id)
          end.to change(StravaRequest, :count).by(15)
            .and change(StravaJobs::RequestRunner.jobs, :count).by(13)
        end
      end

      strava_integration.reload
      expect(strava_integration.status).to eq("syncing")
      expect(strava_integration.athlete_activity_count).to eq(1817)
      expect(strava_integration.strava_data).to eq target_strava_data.as_json
      expect(strava_integration.proxy_serialized).to eq target_proxy_response.as_json

      requests = StravaRequest.where(strava_integration_id: strava_integration.id).order(:created_at)
      athlete_request = requests.find_by(request_type: :fetch_athlete)
      expect(athlete_request.response_status).to eq("success")
      expect(athlete_request.requested_at).to be_present

      stats_request = requests.find_by(request_type: :fetch_athlete_stats)
      expect(stats_request.response_status).to eq("success")
      expect(stats_request.requested_at).to be_present

      list_requests = requests.where(request_type: :list_activities).order(:id)
      # 1817 activities / 200 per page = 10 pages - plus 3 bonus pages
      expect(list_requests.count).to eq(13)
      expect(list_requests.first.parameters["page"]).to eq(1)
      expect(list_requests.last.parameters["page"]).to eq(13)
      expect(list_requests.pluck(:requested_at).compact).to be_empty
      expect(StravaJobs::RequestRunner.jobs.map { |j| j["args"] }.flatten).to eq(list_requests.pluck(:id))
    end

    context "with gear" do
      let(:bikes_json) { '[{"id":"b10186458","name":"Bikeshare","weight":40.0,"primary":false,"retired":false,"distance":130434,"nickname":"Bikeshare","brand_name":"Lyft?","frame_type":4,"model_name":"Bike","description":null,"resource_state":3,"converted_distance":81.0},{"id":"b12596200","name":"Cuttie","weight":20.0,"primary":false,"retired":false,"distance":3669429,"nickname":"Cuttie","brand_name":"Salsa","frame_type":5,"model_name":"Cutthroat","description":null,"resource_state":3,"converted_distance":2280.1}]' }
      let(:shoes_json) { '[{"id":"g21560884","name":"On Cloudvista","primary":false,"retired":false,"distance":88266,"nickname":null,"brand_name":"On","model_name":"Cloudvista","description":null,"resource_state":3,"converted_distance":54.8,"notification_distance":0}]' }
      let(:bikes) { JSON.parse(bikes_json) }
      let(:shoes) { JSON.parse(shoes_json) }

      it "includes gear in proxy_serialized" do
        VCR.use_cassette("strava-get_athlete") do
          VCR.use_cassette("strava-get_athlete_stats") do
            expect do
              instance.perform(strava_integration.id)
            end.to change(StravaRequest, :count).by(15)
              .and change(StravaJobs::RequestRunner.jobs, :count).by(13)
          end
        end
        strava_integration.reload

        (bikes + shoes).each { |gear_data| StravaGear.update_from_strava(strava_integration, gear_data) }

        expect(strava_integration.status).to eq("syncing")
        expect(strava_integration.athlete_activity_count).to eq(1817)
        expect(strava_integration.strava_data).to eq target_strava_data.as_json
        proxy_serialized = strava_integration.proxy_serialized
        expect(proxy_serialized["shoes"]).to eq shoes
        expect(proxy_serialized["bikes"]).to eq bikes
        expect(strava_integration.proxy_serialized).to eq target_proxy_response.as_json
      end
    end

    context "when fetch_athlete_stats returns 429" do
      it "re-enqueues stats, continues with athlete update and list_activities" do
        VCR.use_cassette("strava-get_athlete") do
          VCR.use_cassette("strava-get_athlete_stats_rate_limited") do
            expect do
              instance.perform(strava_integration.id)
            end.to change(StravaRequest, :count).by(5)
              .and change(StravaJobs::RequestRunner.jobs, :count).by(2)
          end
        end

        requests = StravaRequest.where(strava_integration_id: strava_integration.id)

        athlete_request = requests.find_by(request_type: :fetch_athlete)
        expect(athlete_request.response_status).to eq("success")

        stats_request = requests.find_by(request_type: :fetch_athlete_stats, response_status: :rate_limited)
        expect(stats_request).to be_present

        re_enqueued = requests.where(request_type: :fetch_athlete_stats, response_status: :pending, requested_at: nil)
        expect(re_enqueued.count).to eq(1)

        expect(requests.where(request_type: :list_activities).count).to be > 0
      end
    end

    context "when fetch_athlete returns 500" do
      it "raises and does not re-enqueue" do
        expect {
          VCR.use_cassette("strava-get_athlete_500") do
            instance.perform(strava_integration.id)
          end
        }.to raise_error(/Strava API error 500/)

        requests = StravaRequest.where(strava_integration_id: strava_integration.id)
        error_request = requests.find_by(request_type: :fetch_athlete, response_status: :error)
        expect(error_request).to be_present
        expect(error_request.parameters["error_response_status"]).to eq(500)

        expect(requests.count).to eq(1)
      end
    end

    it "does nothing when integration not found" do
      expect {
        instance.perform(-1)
      }.not_to change(StravaRequest, :count)
    end
  end
end
