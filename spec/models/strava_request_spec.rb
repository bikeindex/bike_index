require "rails_helper"

RSpec.describe StravaRequest, type: :model do
  describe "enums" do
    it "has request_type enum" do
      expect(StravaRequest::REQUEST_TYPE_ENUM.keys).to eq(%i[fetch_athlete fetch_athlete_stats list_activities fetch_activity])
    end

    it "has response_status enum" do
      expect(StravaRequest::RESPONSE_STATUS_ENUM.keys).to eq(%i[pending success error rate_limited token_refresh_failed])
    end
  end

  describe "validations" do
    it "requires strava_integration_id" do
      request = StravaRequest.new(endpoint: "athlete", request_type: :fetch_athlete)
      expect(request).not_to be_valid
      expect(request.errors[:strava_integration_id]).to be_present
    end

    it "requires endpoint" do
      si = FactoryBot.create(:strava_integration)
      request = StravaRequest.new(strava_integration_id: si.id, request_type: :fetch_athlete)
      expect(request).not_to be_valid
      expect(request.errors[:endpoint]).to be_present
    end
  end

  describe ".next_pending" do
    let(:si) { FactoryBot.create(:strava_integration) }

    it "returns oldest unprocessed request" do
      older = FactoryBot.create(:strava_request, strava_integration: si, created_at: 2.minutes.ago)
      FactoryBot.create(:strava_request, strava_integration: si, created_at: 1.minute.ago)
      expect(StravaRequest.next_pending).to eq(older)
    end

    it "excludes processed requests" do
      FactoryBot.create(:strava_request, :processed, strava_integration: si)
      pending_req = FactoryBot.create(:strava_request, strava_integration: si)
      expect(StravaRequest.next_pending).to eq(pending_req)
    end

    it "returns nil when no pending requests" do
      expect(StravaRequest.next_pending).to be_nil
    end
  end
end
