require "rails_helper"

RSpec.describe ReviewImpoundClaimsController, type: :request do
  base_url = "/review_impound_claims"
  include_context :request_spec_logged_in_as_user_if_present
  let(:impound_record) { FactoryBot.create(:impound_record, user: current_user, bike: bike_claimed) }
  let(:bike_claimed) { FactoryBot.create(:bike, :with_ownership_claimed, user: current_user) }
  let(:impound_claim) { FactoryBot.create(:impound_claim, :with_stolen_record, status: status, impound_record: impound_record) }
  let(:bike_submitting) { impound_claim.bike_submitting }
  let(:status) { "submitting" }

  describe "show" do
    it "renders" do
      impound_claim.reload
      expect(impound_record.reload.organized?).to be_falsey
      expect(impound_record.authorized?(current_user)).to be_truthy
      expect(bike_claimed.reload.status).to eq "status_impounded"
      expect(bike_submitting)
      expect(current_user.authorized?(bike_claimed)).to be_truthy
      expect(current_user.authorized?(bike_submitting)).to be_falsey
      get "#{base_url}/#{impound_claim.to_param}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
      expect(assigns(:impound_claim)).to eq impound_claim
    end
    context "not users impound_record" do
      let(:impound_record) { FactoryBot.create(:impound_record) }
      it "raises" do
        expect(impound_record.reload.authorized?(current_user)).to be_falsey
        expect {
          get "#{base_url}/#{impound_claim.to_param}"
        }.to raise_error(ActiveRecord::RecordNotFound)
        # unless user is a superuser
        current_user.update(superuser: true)
        get "#{base_url}/#{impound_claim.to_param}"
        expect(response.status).to eq(200)
        expect(response).to render_template(:show)
        expect(assigns(:impound_claim)).to eq impound_claim
      end
    end
    context "organized impound_record" do
      let(:impound_record) { FactoryBot.create(:impound_record_with_organization, user: current_user) }
      it "redirects" do
        impound_claim.reload
        expect(impound_record.reload.organized?).to be_truthy
        get "#{base_url}/#{impound_claim.to_param}"
        expect(response).to redirect_to organization_impound_claim_path(impound_claim.id, organization_id: impound_record.organization_id)
      end
    end
  end
end
