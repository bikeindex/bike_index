require "rails_helper"

RSpec.describe StravaRequest, type: :model do
  describe "validations" do
    it "requires strava_integration_id" do
      request = StravaRequest.new(endpoint: "athlete", request_type: :fetch_athlete)
      expect(request).not_to be_valid
      expect(request.errors[:strava_integration_id]).to be_present
    end

    it "requires endpoint" do
      strava_integration = FactoryBot.create(:strava_integration)
      request = StravaRequest.new(strava_integration_id: strava_integration.id, request_type: :fetch_athlete)
      expect(request).not_to be_valid
      expect(request.errors[:endpoint]).to be_present
    end
  end

  describe ".next_pending" do
    let(:strava_integration) { FactoryBot.create(:strava_integration) }

    it "returns oldest unprocessed request" do
      older = FactoryBot.create(:strava_request, strava_integration:, created_at: 2.minutes.ago)
      FactoryBot.create(:strava_request, strava_integration:, created_at: 1.minute.ago)
      expect(StravaRequest.next_pending).to eq(older)
    end

    it "excludes processed requests" do
      FactoryBot.create(:strava_request, :processed, strava_integration:)
      pending_req = FactoryBot.create(:strava_request, strava_integration:)
      expect(StravaRequest.next_pending).to eq(pending_req)
    end

    it "returns nil when no pending requests" do
      expect(StravaRequest.next_pending).to be_nil
    end
  end
end
