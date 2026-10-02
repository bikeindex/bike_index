# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::StravaIntegrationsController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let!(:strava_integration) { FactoryBot.create(:strava_integration, :synced) }

  base_url = "/admin/strava_integrations"

  describe "#index" do
    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:collection).pluck(:id)).to eq([strava_integration.id])
    end

    context "sorted by athlete ID" do
      let!(:strava_integration) { FactoryBot.create(:strava_integration, :synced, strava_id: "9") }
      let!(:strava_integration_larger) { FactoryBot.create(:strava_integration, :synced, strava_id: "10") }

      it "sorts numerically" do
        get base_url, params: {sort: "strava_id", direction: "asc"}
        expect(response.status).to eq(200)
        expect(assigns(:collection).pluck(:id)).to eq([strava_integration.id, strava_integration_larger.id])
      end
    end
  end

  describe "#show" do
    it "responds with ok" do
      get "#{base_url}/#{strava_integration.id}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
    end

    context "with strava gear" do
      let!(:strava_gear) { FactoryBot.create(:strava_gear, strava_integration:) }

      it "renders gear table" do
        get "#{base_url}/#{strava_integration.id}"
        expect(response.status).to eq(200)
        expect(response.body).to include(strava_gear.strava_gear_display_name)
      end
    end
  end
end
