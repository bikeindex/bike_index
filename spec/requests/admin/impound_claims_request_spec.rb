require "rails_helper"

base_url = "/admin/impound_claims"
RSpec.describe Admin::ImpoundClaimsController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    let!(:impound_claim) { FactoryBot.create(:impound_claim) }
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:impound_claims)).to eq([impound_claim])
    end
  end

  describe "show" do
    let!(:impound_claim) { FactoryBot.create(:impound_claim) }
    it "renders" do
      get "#{base_url}/#{impound_claim.id}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
    end
  end
end
