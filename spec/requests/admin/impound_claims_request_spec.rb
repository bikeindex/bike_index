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

      impound_claim_later = FactoryBot.create(:impound_claim)
      impound_claim.update(impound_record: FactoryBot.create(:impound_record, organization: impound_claim.organization))
      get base_url, params: {sort: "impound_record_id", direction: "desc"}
      expect(response.status).to eq(200)
      expect(assigns(:impound_claims)).to eq([impound_claim, impound_claim_later])
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
