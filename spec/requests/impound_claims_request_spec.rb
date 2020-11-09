require "rails_helper"

RSpec.describe ImpoundClaimsController, type: :request do
  base_url = "/impound_claims"
  include_context :request_spec_logged_in_as_user_if_present
  let(:impound_record) { FactoryBot.create(:impound_record) }
  let(:bike_claimed) { impound_record.bike }
  let(:bike_submitted) { FactoryBot.create(:bike, :with_stolen_record, :with_ownership_claimed, user: current_user) }
  let(:stolen_record) { bike_submitted.current_stolen_record }

  describe "create" do
    it "creates an impound claim for a stolen bike" do
      impound_record.reload
      expect(impound_record.active?).to be_truthy
      expect(stolen_record).to be_valid
      expect(stolen_record.user&.id).to eq current_user.id
      expect do
        post base_url, params: {
          impound_claim: {
            impound_record_id: impound_record.id,
            stolen_record_id: stolen_record.id
          }
        }
      end.to change(ImpoundClaim, :count).by 1
      expect(flash[:success]).to be_present
      impound_claim = ImpoundClaim.last
      expect(impound_claim.status).to eq "pending"
      expect(impound_claim.user&.id).to eq current_user.id
      expect(impound_claim.bike_submitted&.id).to eq bike_submitted.id
      expect(impound_claim.bike_claimed&.id).to eq bike_claimed.id
    end
    context "not a current impound_record" do
      let(:impound_record) { FactoryBot.create(:impound_record_resolved) }
      it "errors" do
        expect do
          post base_url, params: {
            impound_claim: {
              impound_record_id: impound_record.id,
              stolen_record_id: stolen_record.id
            }
          }
        end.to_not change(ImpoundClaim, :count)
        expect(impound_record.active?).to be_falsey
        expect(flash[:error]).to eq "That impounded bike record has been marked 'Owner retrieved bike' and cannot be claimed"
      end
    end
    context "not users stolen bike" do
      let(:bike_submitted) { FactoryBot.create(:bike, :with_stolen_record, :with_ownership_claimed) }
      it "errors" do
        expect do
          post base_url, params: {
            impound_claim: {
              impound_record_id: impound_record.id,
              stolen_record_id: stolen_record.id
            }
          }
        end.to_not change(ImpoundClaim, :count)
        expect(flash[:error]).to match(/own/i)
      end
    end
  end
end
