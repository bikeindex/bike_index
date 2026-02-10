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

  describe ".next_pending" do
    let(:strava_integration) { FactoryBot.create(:strava_integration) }

    it "returns oldest unprocessed request" do
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

    it "respects limit parameter" do
      3.times { FactoryBot.create(:strava_request, strava_integration:) }
      expect(StravaRequest.next_pending(2).count).to eq(2)
    end

    it "orders by priority: list_activities, fetch_gear, fetch_activity" do
      fetch_activity = FactoryBot.create(:strava_request, :fetch_activity, strava_integration:)
      list_activities = FactoryBot.create(:strava_request, :list_activities, strava_integration:)
      fetch_gear = FactoryBot.create(:strava_request, :fetch_gear, strava_integration:)

      results = StravaRequest.next_pending(10).to_a
      expect(results).to eq([list_activities, fetch_gear, fetch_activity])
    end

    it "orders by id within the same priority" do
      first = FactoryBot.create(:strava_request, :fetch_activity, strava_integration:)
      second = FactoryBot.create(:strava_request, :fetch_activity, strava_integration:)

      results = StravaRequest.next_pending(10).to_a
      expect(results).to eq([first, second])
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

  describe ".estimated_current_rate_limit" do
    let(:strava_integration) { FactoryBot.create(:strava_integration) }
    let(:rate_limit) do
      {"short_limit" => 100, "short_usage" => 10, "long_limit" => 1000, "long_usage" => 200,
       "read_short_limit" => 100, "read_short_usage" => 10, "read_long_limit" => 1000, "read_long_usage" => 200}
    end

    it "returns defaults when no requests have rate_limit" do
      result = StravaRequest.estimated_current_rate_limit
      expect(result["short_limit"]).to eq 200
      expect(result["short_usage"]).to eq 0
      expect(result["long_limit"]).to eq 2000
      expect(result["long_usage"]).to eq 0
    end

    context "with a recent request in the same short period" do
      let(:boundary) { Time.current.change(min: (Time.current.min / 15) * 15, sec: 0) }
      let!(:base_request) do
        FactoryBot.create(:strava_request, :processed, strava_integration:,
          requested_at: boundary + 1.second, rate_limit:)
      end

      it "returns the usage from the latest rate_limit" do
        result = StravaRequest.estimated_current_rate_limit
        expect(result["short_limit"]).to eq 100
        expect(result["short_usage"]).to eq 10
        expect(result["long_limit"]).to eq 1000
        expect(result["long_usage"]).to eq 200
        expect(result["read_short_usage"]).to eq 10
        expect(result["read_long_usage"]).to eq 200
      end
    end

    context "when the 15-minute boundary has been crossed" do
      let(:boundary) { Time.current.change(min: (Time.current.min / 15) * 15, sec: 0) }
      let!(:base_request) do
        FactoryBot.create(:strava_request, :processed, strava_integration:,
          requested_at: boundary - 2.minutes, rate_limit:)
      end

      it "resets short usage to 0" do
        result = StravaRequest.estimated_current_rate_limit
        expect(result["short_limit"]).to eq 100
        expect(result["short_usage"]).to eq 0
        expect(result["read_short_usage"]).to eq 0
        expect(result["long_usage"]).to eq 200
        expect(result["read_long_usage"]).to eq 200
      end
    end

    context "when the daily boundary has been crossed" do
      let(:daily_boundary) { Time.current.utc.beginning_of_day }
      let!(:base_request) do
        FactoryBot.create(:strava_request, :processed, strava_integration:,
          requested_at: daily_boundary - 1.hour, rate_limit:)
      end

      it "resets both short and long usage to 0" do
        result = StravaRequest.estimated_current_rate_limit
        expect(result["short_usage"]).to eq 0
        expect(result["long_usage"]).to eq 0
        expect(result["read_short_usage"]).to eq 0
        expect(result["read_long_usage"]).to eq 0
      end
    end
  end
end
