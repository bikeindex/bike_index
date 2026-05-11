# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::StravaActivitiesController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let!(:strava_activity) { FactoryBot.create(:strava_activity) }

  base_url = "/admin/strava_activities"

  describe "#index" do
    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:collection).pluck(:id)).to eq([strava_activity.id])
    end

    context "with nil distance_meters" do
      let!(:strava_activity) { FactoryBot.create(:strava_activity, distance_meters: nil) }

      it "responds with ok" do
        get base_url
        expect(response.status).to eq(200)
        expect(assigns(:collection).pluck(:id)).to eq([strava_activity.id])
      end
    end
  end
end
