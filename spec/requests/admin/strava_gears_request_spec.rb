# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::StravaGearsController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let!(:strava_gear) { FactoryBot.create(:strava_gear) }

  base_url = "/admin/strava_gears"

  describe "#index" do
    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:collection).pluck(:id)).to eq([strava_gear.id])
    end

    context "with search_strava_integration_id" do
      it "filters by strava_integration_id" do
        other_gear = FactoryBot.create(:strava_gear)
        get base_url, params: {search_strava_integration_id: strava_gear.strava_integration_id}
        expect(assigns(:collection).pluck(:id)).to eq([strava_gear.id])
      end
    end
  end
end
