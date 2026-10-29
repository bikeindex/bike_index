require "rails_helper"

RSpec.describe Admin::LoggedSearchesController, type: :request do
  base_url = "/admin/logged_searches"

  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    let!(:logged_search) { FactoryBot.create(:logged_search) }
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:logged_searches).pluck(:id)).to eq([logged_search.id])
    end

    context "with a bikebook search" do
      let!(:logged_search) { FactoryBot.create(:logged_search, endpoint: :web_bikes) }
      let!(:bikebook_search) { FactoryBot.create(:logged_search, endpoint: :web_bikebook) }
      let!(:ebike_rules_search) { FactoryBot.create(:logged_search, endpoint: :web_ebike_rules) }
      it "filters to not_web_bikebook" do
        get base_url, params: {search_endpoint: "not_web_bikebook"}
        expect(response.status).to eq(200)
        expect(assigns(:logged_searches).pluck(:id)).to eq([logged_search.id])
      end
    end
  end
end
