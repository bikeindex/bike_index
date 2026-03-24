# frozen_string_literal: true

require "rails_helper"

RSpec.describe StravaJobs::EnqueueEnrichActivities, type: :job do
  describe "enqueue_enrich_activity_requests" do
    let(:strava_integration) { FactoryBot.create(:strava_integration) }
    before { StravaRequest.destroy_all }

    context "when enrich_requests_rate_limited?" do
      it "does not create fetch_activity requests" do
        FactoryBot.create(:strava_activity, strava_integration:, strava_id: "12345")
        allow(StravaJobs::RequestRunner).to receive(:enrich_requests_rate_limited?).and_return(true)

        described_class.new.perform(strava_integration.id)

        activity_requests = StravaRequest.where(strava_integration_id: strava_integration.id, request_type: :fetch_activity)
        expect(activity_requests.count).to eq(0)
      end
    end
  end

  describe "enqueue_gear_requests" do
    let(:strava_integration) { FactoryBot.create(:strava_integration) }
    before { StravaRequest.destroy_all }

    it "creates fetch_gear requests for un_enriched gear" do
      FactoryBot.create(:strava_gear, strava_integration:, strava_id: "b1234",
        strava_data: {"resource_state" => 2})
      FactoryBot.create(:strava_gear, strava_integration:, strava_id: "b5678",
        strava_data: {"resource_state" => 3})
      described_class.new.perform(strava_integration.id)
      gear_requests = StravaRequest.where(strava_integration_id: strava_integration.id, request_type: :fetch_gear)
      expect(gear_requests.count).to eq(1)
      expect(gear_requests.first.parameters["strava_gear_id"]).to eq("b1234")
    end

    it "creates fetch_gear requests for unknown gear ids" do
      FactoryBot.create(:strava_activity, strava_integration:, gear_id: "b9999")
      described_class.new.perform(strava_integration.id)
      gear_requests = StravaRequest.where(strava_integration_id: strava_integration.id, request_type: :fetch_gear)
      expect(gear_requests.count).to eq(1)
      expect(gear_requests.first.parameters["strava_gear_id"]).to eq("b9999")
    end

    it "does not create duplicate requests" do
      FactoryBot.create(:strava_gear, strava_integration:, strava_id: "b1234",
        strava_data: {"resource_state" => 2})
      described_class.new.perform(strava_integration.id)
      described_class.new.perform(strava_integration.id)
      gear_requests = StravaRequest.where(strava_integration_id: strava_integration.id, request_type: :fetch_gear)
      expect(gear_requests.count).to eq(1)
    end
  end
end
