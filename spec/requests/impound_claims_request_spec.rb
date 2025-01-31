require "rails_helper"

RSpec.describe ImpoundClaimsController, type: :request do
  base_url = "/impound_claims"
  include_context :request_spec_logged_in_as_user_if_present
  let(:impound_record) { FactoryBot.create(:impound_record) }
  let(:bike_claimed) { impound_record.bike }
  let(:bike_submitting) { FactoryBot.create(:bike, :with_stolen_record, :with_ownership_claimed, user: current_user) }
  let(:stolen_record) { bike_submitting.current_stolen_record }

  describe "create" do
    it "creates an impound claim for a stolen bike" do
      impound_record.reload
      expect(impound_record.active?).to be_truthy
      expect(stolen_record).to be_valid
      expect(stolen_record.user&.id).to eq current_user.id
      expect {
        post base_url, params: {
          impound_claim: {
            impound_record_id: impound_record.id,
            stolen_record_id: stolen_record.id
          }
        }
      }.to change(ImpoundClaim, :count).by 1
      expect(flash[:success]).to be_present
      impound_claim = ImpoundClaim.last
      expect(impound_claim.status).to eq "pending"
      expect(impound_claim.user&.id).to eq current_user.id
      expect(impound_claim.bike_submitting&.id).to eq bike_submitting.id
      expect(impound_claim.bike_claimed&.id).to eq bike_claimed.id
    end
    context "not a current impound_record" do
      let(:impound_record) { FactoryBot.create(:impound_record_resolved) }
      it "errors" do
        expect {
          post base_url, params: {
            impound_claim: {
              impound_record_id: impound_record.id,
              stolen_record_id: stolen_record.id
            }
          }
        }.to_not change(ImpoundClaim, :count)
        expect(impound_record.active?).to be_falsey
        expect(flash[:error]).to eq "That found bike record has been marked 'Owner retrieved bike' and cannot be claimed"
      end
    end
    context "user has a submitting claim" do
      let!(:impound_claim) { FactoryBot.create(:impound_claim_with_stolen_record, impound_record: impound_record, user: current_user, status: status) }
      (ImpoundClaim.statuses - %w[denied canceled]).each do |checked_status|
        context "status: #{checked_status}" do
          let(:status) { checked_status }
          it "errors" do
            expect(impound_claim.status).to eq status
            expect(impound_claim.bike_claimed_id).to eq bike_claimed.id
            expect {
              post base_url, params: {
                impound_claim: {
                  impound_record_id: impound_record.id,
                  stolen_record_id: stolen_record.id
                }
              }
            }.to_not change(ImpoundClaim, :count)
            expect(flash[:error]).to eq "You already have a #{ImpoundClaim.status_humanized(status)} claim for that found bike!"
          end
        end
      end
      context "status: denied" do
        let(:status) { "denied" }
        it "creates" do
          expect {
            post base_url, params: {
              impound_claim: {
                impound_record_id: impound_record.id,
                stolen_record_id: stolen_record.id
              }
            }
          }.to change(ImpoundClaim, :count).by 1
          expect(flash[:success]).to be_present
          impound_claim = ImpoundClaim.last
          expect(impound_claim.status).to eq "pending"
          expect(impound_claim.user&.id).to eq current_user.id
          expect(impound_claim.bike_submitting&.id).to eq bike_submitting.id
          expect(impound_claim.bike_claimed&.id).to eq bike_claimed.id
        end
      end
      context "status: canceled" do
        let(:status) { "canceled" }
        it "creates" do
          expect {
            post base_url, params: {
              impound_claim: {
                impound_record_id: impound_record.id,
                stolen_record_id: stolen_record.id
              }
            }
          }.to change(ImpoundClaim, :count).by 1
          expect(flash[:success]).to be_present
          impound_claim = ImpoundClaim.last
          expect(impound_claim.status).to eq "pending"
          expect(impound_claim.user&.id).to eq current_user.id
          expect(impound_claim.bike_submitting&.id).to eq bike_submitting.id
          expect(impound_claim.bike_claimed&.id).to eq bike_claimed.id
        end
      end
    end
    context "not users stolen bike" do
      let(:bike_submitting) { FactoryBot.create(:bike, :with_stolen_record, :with_ownership_claimed) }
      it "errors" do
        expect {
          post base_url, params: {
            impound_claim: {
              impound_record_id: impound_record.id,
              stolen_record_id: stolen_record.id
            }
          }
        }.to_not change(ImpoundClaim, :count)
        expect(flash[:error]).to match(/own/i)
      end
    end
  end

  describe "update" do
    let(:impound_claim) { FactoryBot.create(:impound_claim, impound_record: impound_record, user: current_user) }
    it "updates" do
      patch "#{base_url}/#{impound_claim.id}", params: {
        impound_claim: {message: "A new message", status: "approved"}
      }
      expect(flash[:success]).to be_present
      expect(flash[:success]).to_not match(/submit/)
      impound_claim.reload
      expect(impound_claim.message).to eq "A new message"
      expect(impound_claim.status).to eq "pending"
    end
    context "with status submitted" do
      it "submits" do
        patch "#{base_url}/#{impound_claim.id}", params: {
          impound_claim: {message: "I'm submitting", status: "submitting"}
        }
        expect(flash[:success]).to match(/submit/)
        impound_claim.reload
        expect(impound_claim.message).to eq "I'm submitting"
        expect(impound_claim.status).to eq "submitting"
        expect(impound_claim.submitted?).to be_truthy
      end
    end
    context "submitted claim" do
      let(:impound_claim) { FactoryBot.create(:impound_claim, impound_record: impound_record, user: current_user, status: "submitting") }
      it "does not update" do
        patch "#{base_url}/#{impound_claim.id}", params: {
          impound_claim: {message: "A new message", status: "pending"}
        }
        expect(response.status).to eq 404
        impound_claim.reload
        expect(impound_claim.message).to be_blank
        expect(impound_claim.status).to eq "submitting"
      end
    end
    context "not users impound_claim" do
      let(:impound_claim) { FactoryBot.create(:impound_claim, impound_record: impound_record) }
      it "does not update" do
        patch "#{base_url}/#{impound_claim.id}", params: {
          impound_claim: {message: "A new message"}
        }
        expect(response.status).to eq 404
        impound_claim.reload
        expect(impound_claim.message).to be_blank
      end
    end
  end
end
