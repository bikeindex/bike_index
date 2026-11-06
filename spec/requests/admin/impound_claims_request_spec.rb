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

    context "search_status current" do
      let!(:impound_claim_resolved) { FactoryBot.create(:impound_claim, status: "denied") }
      # Written because it 500'd: ImpoundClaim has no current scope
      it "renders only active claims" do
        get base_url, params: {search_status: "current"}
        expect(response.status).to eq(200)
        expect(assigns(:impound_claims).pluck(:id)).to eq([impound_claim.id])
        expect(response.body).to include("Current records")
      end
    end

    context "search_status stalled" do
      let(:impound_record) { FactoryBot.create(:impound_record) }
      let!(:impound_claim_stalled) { FactoryBot.create(:impound_claim, impound_record:, status: "submitting", submitted_at: Time.current - 100.days) }
      let!(:impound_claim_recent) { FactoryBot.create(:impound_claim, impound_record:, status: "submitting") }

      it "renders only stalled claims" do
        get base_url, params: {search_status: "stalled", render_chart: true}
        expect(response.status).to eq(200)
        expect(assigns(:impound_claims).pluck(:id)).to eq([impound_claim_stalled.id])
        expect(response.body).to include("Stalled records")
      end
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
