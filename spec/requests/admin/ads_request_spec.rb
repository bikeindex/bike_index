require "rails_helper"

base_url = "/admin/ads"
RSpec.describe Admin::AdsController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    let!(:ad) { Ad.create(title: "Ad title", body: "Ad body", organization: FactoryBot.create(:organization)) }

    it "responds with OK and renders the index template" do
      get base_url

      expect(response).to be_ok
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(response.body).to include(ad.title)
    end
  end
end
