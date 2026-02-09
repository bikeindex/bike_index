require "rails_helper"

RSpec.describe Admin::StravaRequestsController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let!(:strava_request) { FactoryBot.create(:strava_request) }

  base_url = "/admin/strava_requests"

  describe "#index" do
    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:collection).pluck(:id)).to eq([strava_request.id])
    end
  end
end
