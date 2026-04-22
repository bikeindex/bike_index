# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaRequest, type: :model do
  describe "validations" do
    it "requires strava_integration_id" do
      request = StravaRequest.new(request_type: :fetch_athlete)
      expect(request).not_to be_valid
      expect(request.errors[:strava_integration_id]).to be_present
    end
  end

  describe "priority" do
    it "has the same keys for PRIORITY_MAP and REQUEST_TYPE" do
      expect(StravaRequest::REQUEST_TYPE_ENUM.keys.sort).to eq StravaRequest::PRIORITY_MAP.keys.sort
    end
  end

  describe ".next_pending" do
    before { StravaRequest.destroy_all }
    let(:strava_integration) { FactoryBot.create(:strava_integration) }

    it "returns oldest pending request" do
      older = FactoryBot.create(:strava_request, strava_integration:, created_at: 2.minutes.ago)
      FactoryBot.create(:strava_request, strava_integration:, created_at: 1.minute.ago)
      expect(StravaRequest.next_pending.first).to eq(older)
    end

    it "excludes processed requests" do
      FactoryBot.create(:strava_request, :processed, strava_integration:)
      pending_req = FactoryBot.create(:strava_request, strava_integration:)
      expect(StravaRequest.next_pending.first).to eq(pending_req)
    end

    it "returns empty when no pending requests" do
      expect(StravaRequest.next_pending).to be_empty
    end

    it "orders by priority: list_activities, fetch_gear, fetch_activity" do
      fetch_activity = FactoryBot.create(:strava_request, :fetch_activity, strava_integration:)
      list_activities = FactoryBot.create(:strava_request, :list_activities, strava_integration:)
      fetch_gear = FactoryBot.create(:strava_request, :fetch_gear, strava_integration:)

      results = StravaRequest.next_pending(10).pluck(:id)
      expect(results).to eq([list_activities.id, fetch_gear.id, fetch_activity.id])
    end

    it "orders by id within the same priority" do
      first = FactoryBot.create(:strava_request, :fetch_activity, strava_integration:)
      second = FactoryBot.create(:strava_request, :fetch_activity, strava_integration:)
      third = FactoryBot.create(:strava_request, :fetch_activity, priority: 1)

      results = StravaRequest.next_pending(10).pluck(:id)
      expect(results).to eq([third.id, first.id, second.id])
    end
  end

  describe ".parse_rate_limit" do
    it "parses rate limit headers" do
      headers = {"X-RateLimit-Limit" => "100,1000", "X-RateLimit-Usage" => "50,350",
                 "X-ReadRateLimit-Limit" => "100,1000", "X-ReadRateLimit-Usage" => "50,350"}
      result = StravaRequest.parse_rate_limit(headers)
      expect(result).to eq({short_limit: 100, short_usage: 50, long_limit: 1000, long_usage: 350,
                            read_short_limit: 100, read_short_usage: 50, read_long_limit: 1000, read_long_usage: 350})
    end

    it "returns nil when no rate limit headers" do
      expect(StravaRequest.parse_rate_limit({})).to be_nil
    end

    it "handles missing read headers" do
      headers = {"X-RateLimit-Limit" => "100,1000", "X-RateLimit-Usage" => "10,200"}
      result = StravaRequest.parse_rate_limit(headers)
      expect(result).to eq({short_limit: 100, short_usage: 10, long_limit: 1000, long_usage: 200})
    end
  end

  describe "looks_like_last_page?" do
    let(:strava_integration) { FactoryBot.create(:strava_integration, athlete_activity_count: 200) }

    it "returns true when on expected last page" do
      strava_request = FactoryBot.create(:strava_request, :list_activities, strava_integration:)
      expect(strava_request.looks_like_last_page?).to be true
    end

    it "returns false when not on expected last page" do
      strava_integration.update(athlete_activity_count: 400)
      strava_request = FactoryBot.create(:strava_request, :list_activities, strava_integration:)
      expect(strava_request.looks_like_last_page?).to be false
    end

    it "returns false for fetch_activity requests" do
      strava_request = FactoryBot.create(:strava_request, :fetch_activity, strava_integration:)
      expect(strava_request.looks_like_last_page?).to be false
    end
  end

  describe "skip_request?" do
    let(:strava_integration) { FactoryBot.create(:strava_integration) }

    it "returns false for non-fetch_activity requests" do
      strava_request = FactoryBot.create(:strava_request, :list_activities, strava_integration:)
      expect(strava_request.skip_request?).to be false
    end

    it "returns false when activity is not enriched" do
      FactoryBot.create(:strava_activity, strava_integration:, strava_id: "12345")
      strava_request = FactoryBot.create(:strava_request, :fetch_activity, strava_integration:)
      expect(strava_request.skip_request?).to be false
    end

    it "returns true when activity was recently enriched" do
      FactoryBot.create(:strava_activity, strava_integration:, strava_id: "12345",
        enriched_at: 30.minutes.ago)
      strava_request = FactoryBot.create(:strava_request, :fetch_activity, strava_integration:)
      expect(strava_request.skip_request?).to be true
    end

    it "returns false when activity was enriched longer ago than RE_ENRICH_AFTER" do
      FactoryBot.create(:strava_activity, strava_integration:, strava_id: "12345",
        enriched_at: 2.hours.ago)
      strava_request = FactoryBot.create(:strava_request, :fetch_activity, strava_integration:)
      expect(strava_request.skip_request?).to be false
    end
  end

  describe "update_from_response" do
    let(:strava_integration) { FactoryBot.create(:strava_integration) }
    let!(:strava_request) { FactoryBot.create(:strava_request, :list_activities, strava_integration:) }
    let(:headers) { {"X-RateLimit-Limit" => "100,1000", "X-RateLimit-Usage" => "10,200"} }

    context "500 response" do
      let(:response) { instance_double(Faraday::Response, success?: false, status: 500, headers:, body: "Internal Server Error") }

      it "stores error response in parameters" do
        strava_request.update_from_response(response)
        expect(strava_request.error?).to be true
        expect(strava_request.parameters).to eq({page: 1, error_response_status: 500}.as_json)
      end

      context "with raise_on_error" do
        it "raises and stores the error_response_status" do
          expect do
            strava_request.update_from_response(response, raise_on_error: true)
          end.to raise_error(/Strava API error 500/)

          expect(strava_request.reload.error?).to be true
          expect(strava_request.parameters).to eq({page: 1, error_response_status: 500}.as_json)
        end
      end
    end

    context "503 service unavailable" do
      let(:response) { instance_double(Faraday::Response, success?: false, status: 503, headers:, body: "Service Unavailable") }
      let(:target_parameters) { strava_request.parameters.merge(error_response_status: 503).as_json }

      it "marks as error, doesn't raise and re-enqueues a new request" do
        expect {
          strava_request.update_from_response(response, re_enqueue_if_rate_limited_or_unavailable: true)
        }.to change(StravaRequest, :count).by(1)

        expect(strava_request.reload.error?).to be true
        expect(strava_request.parameters).to eq target_parameters

        new_request = StravaRequest.last
        expect(new_request.id).not_to eq strava_request.id
        expect(new_request.request_type).to eq strava_request.request_type
        expect(new_request.parameters).not_to have_key("error_response_status")
      end

      context "without re_enqueue_if_rate_limited_or_unavailable" do
        it "marks as error but does not re-enqueue" do
          expect {
            strava_request.update_from_response(response)
          }.not_to change(StravaRequest, :count)

          expect(strava_request.error?).to be true
          expect(strava_request.parameters).to eq target_parameters
        end
      end
    end

    context "successful response" do
      let(:response) { instance_double(Faraday::Response, success?: true, status: 200, headers:, body: []) }

      it "does not store error_response_status" do
        strava_request.update_from_response(response)
        expect(strava_request.success?).to be true
        expect(strava_request.parameters).not_to have_key("error_response_status")
      end
    end

    context "404 record not found" do
      let(:response) do
        instance_double(Faraday::Response, success?: false, status: 404, headers:,
          body: {"message" => "Record Not Found", "errors" => [{"resource" => "Activity", "field" => "id", "code" => "invalid"}]})
      end

      it "marks as error but does not raise even with raise_on_error" do
        expect {
          strava_request.update_from_response(response, raise_on_error: true)
        }.not_to raise_error

        expect(strava_request.reload.error?).to be true
        expect(strava_request.parameters).to eq({page: 1, error_response_status: 404}.as_json)
      end
    end

    context "rate limited response with re_enqueue" do
      let(:response) { instance_double(Faraday::Response, success?: false, status: 429, headers:, body: "Rate limited") }

      it "stores error response and re-enqueues" do
        expect {
          strava_request.update_from_response(response, re_enqueue_if_rate_limited_or_unavailable: true)
        }.to change(StravaRequest, :count).by(1)

        expect(strava_request.rate_limited?).to be true
        expect(strava_request.parameters.keys).to eq(["page"])
      end
    end
  end

  describe ".estimated_current_rate_limit" do
    before { StravaRequest.destroy_all }
    let(:strava_integration) { FactoryBot.create(:strava_integration) }
    let(:rate_limit) do
      {"short_limit" => 100, "short_usage" => 10, "long_limit" => 1000, "long_usage" => 200,
       "read_short_limit" => 100, "read_short_usage" => 10, "read_long_limit" => 1000, "read_long_usage" => 200}
    end
    let(:target) do
      {short_limit: 200, short_usage: 0, long_limit: 2000, long_usage: 0,
       read_short_limit: 200, read_short_usage: 0, read_long_limit: 2000, read_long_usage: 0}
    end

    it "returns defaults when no requests have rate_limit" do
      expect(StravaRequest.estimated_current_rate_limit).to eq target
    end

    context "with a recent request in the same short period" do
      let(:boundary) { Time.current.change(min: (Time.current.min / 15) * 15, sec: 0) }
      let!(:base_request) do
        FactoryBot.create(:strava_request, :processed, strava_integration:,
          requested_at: boundary + 1.second, rate_limit:)
      end
      let(:target) do
        {short_limit: 100, short_usage: 10, long_limit: 1000, long_usage: 200,
         read_short_limit: 100, read_short_usage: 10, read_long_limit: 1000, read_long_usage: 200}
      end

      it "returns the usage from the latest rate_limit" do
        expect(StravaRequest.estimated_current_rate_limit).to eq target
      end
    end

    context "when the 15-minute boundary has been crossed" do
      let(:boundary) { Time.current.change(min: (Time.current.min / 15) * 15, sec: 0) }
      let!(:base_request) do
        FactoryBot.create(:strava_request, :processed, strava_integration:,
          requested_at: boundary - 2.minutes, rate_limit:)
      end
      let(:target) do
        # long usage only resets if boundary - 2.minutes also crossed midnight UTC
        long_usage = (Time.current.utc.beginning_of_day > boundary - 2.minutes) ? 0 : 200
        {short_limit: 100, short_usage: 0, long_limit: 1000, long_usage:,
         read_short_limit: 100, read_short_usage: 0, read_long_limit: 1000, read_long_usage: long_usage}
      end

      it "resets short usage to 0" do
        expect(StravaRequest.estimated_current_rate_limit).to eq target
      end
    end

    context "when only binx_response requests exist" do
      let!(:binx_request) do
        FactoryBot.create(:strava_request, strava_integration:,
          requested_at: Time.current, response_status: :binx_response,
          rate_limit: {"short_limit" => 100, "short_usage" => 99, "long_limit" => 1000, "long_usage" => 999,
                       "read_short_limit" => 100, "read_short_usage" => 99, "read_long_limit" => 1000, "read_long_usage" => 999})
      end

      it "returns defaults" do
        expect(StravaRequest.estimated_current_rate_limit).to eq target
      end
    end

    context "when the most recent request is a binx_response" do
      let(:boundary) { Time.current.change(min: (Time.current.min / 15) * 15, sec: 0) }
      let!(:strava_request) do
        FactoryBot.create(:strava_request, :processed, strava_integration:,
          requested_at: boundary + 1.second, rate_limit:)
      end
      let!(:binx_request) do
        FactoryBot.create(:strava_request, strava_integration:,
          requested_at: boundary + 2.seconds, response_status: :binx_response,
          rate_limit: {"short_limit" => 100, "short_usage" => 99, "long_limit" => 1000, "long_usage" => 999,
                       "read_short_limit" => 100, "read_short_usage" => 99, "read_long_limit" => 1000, "read_long_usage" => 999})
      end
      let(:target) do
        {short_limit: 100, short_usage: 10, long_limit: 1000, long_usage: 200,
         read_short_limit: 100, read_short_usage: 10, read_long_limit: 1000, read_long_usage: 200}
      end

      it "ignores binx_response and uses the strava response" do
        expect(StravaRequest.estimated_current_rate_limit).to eq target
      end
    end

    context "when the daily boundary has been crossed" do
      let(:daily_boundary) { Time.current.utc.beginning_of_day }
      let!(:base_request) do
        FactoryBot.create(:strava_request, :processed, strava_integration:,
          requested_at: daily_boundary - 1.hour, rate_limit:)
      end
      let(:target) do
        {short_limit: 100, short_usage: 0, long_limit: 1000, long_usage: 0,
         read_short_limit: 100, read_short_usage: 0, read_long_limit: 1000, read_long_usage: 0}
      end

      it "resets both short and long usage to 0" do
        expect(StravaRequest.estimated_current_rate_limit).to eq target
      end
    end
  end
end
