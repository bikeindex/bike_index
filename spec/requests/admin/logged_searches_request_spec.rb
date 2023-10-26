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
  end
end
