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
        get "#{base_url}/#{impound_claim.to_param}"
        expect(response.status).to eq 404
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

  describe "update" do
    before { impound_claim.reload }
    it "flash errors if unknown update" do
      impound_record.reload
      expect(impound_record.impound_record_updates.count).to eq 0
      expect(impound_record.status).to eq "current"
      expect(impound_record.impound_claims.pluck(:id)).to eq([impound_claim.id])
      expect {
        patch "#{base_url}/#{impound_claim.to_param}", params: {
          submit: "Retrieved",
          impound_claim: {response_message: ""}
        }
      }.to_not change(EmailImpoundClaimJob.jobs, :count)
      expect(flash[:error]).to be_present
      expect(response).to redirect_to review_impound_claim_path(impound_claim.id)
      impound_record.reload
      expect(impound_record.status).to eq "current"
      expect(impound_record.impound_record_updates.count).to eq 0
      expect(impound_claim.status).to eq "submitting"
    end
    context "approved" do
      it "updates" do
        expect(impound_claim.status).to eq "submitting"
        impound_record.reload
        expect(impound_record.impound_record_updates.count).to eq 0
        expect(impound_record.status).to eq "current"
        expect(impound_record.impound_claims.pluck(:id)).to eq([impound_claim.id])
        expect(impound_record.update_kinds).to eq(ImpoundRecordUpdate.kinds - %w[move_location expired])
        expect {
          patch "#{base_url}/#{impound_claim.to_param}", params: {
            submit: "Approve",
            impound_claim: {response_message: " "}
          }
        }.to change(EmailImpoundClaimJob.jobs, :count).by(1)
        expect(response).to redirect_to review_impound_claim_path(impound_claim.id)
        expect(assigns(:impound_claim)).to eq impound_claim
        impound_record.reload
        expect(impound_record.status).to eq "current"
        expect(impound_record.update_kinds).to eq(ImpoundRecordUpdate.kinds - %w[move_location claim_approved claim_denied expired])
        expect(impound_record.impound_record_updates.count).to eq 1
        impound_record_update = impound_record.impound_record_updates.last
        expect(impound_record_update.user&.id).to eq current_user.id
        expect(impound_record_update.impound_claim&.id).to eq impound_claim.id
        expect(impound_record_update.kind).to eq "claim_approved"

        impound_claim.reload
        expect(impound_claim.status).to eq "approved"
        expect(impound_claim.impound_record_updates.pluck(:id)).to eq([impound_record_update.id])
        expect(impound_claim.response_message).to eq nil
      end
      context "inline sidekiq" do
        let(:response_message) { "RESponse=MESSAGE<alert>" }
        it "sends a message" do
          EmailImpoundClaimJob.new.perform(impound_claim.id)
          # ensure that the message includes the response_message
          expect(impound_claim.reload.status).to eq "submitting"
          # Verify we sent created a notification already (or else it gets created when sidekiq inlined)
          expect(impound_claim.notifications.pluck(:kind)).to match_array(%w[impound_claim_submitting])
          impound_record.reload
          expect(impound_record.impound_record_updates.count).to eq 0
          expect(impound_record.status).to eq "current"
          expect(impound_record.impound_claims.pluck(:id)).to eq([impound_claim.id])
          expect(impound_record.update_kinds).to eq(ImpoundRecordUpdate.kinds - %w[move_location expired])
          Sidekiq::Job.clear_all
          ActionMailer::Base.deliveries = []
          Sidekiq::Testing.inline! do
            patch "#{base_url}/#{impound_claim.to_param}", params: {
              submit: "approve",
              impound_claim: {response_message: response_message}
            }
          end
          expect(ActionMailer::Base.deliveries.count).to eq 1
          mail = ActionMailer::Base.deliveries.last
          expect(mail.to).to eq([impound_claim.user.email])
          expect(mail.reply_to).to eq([current_user.email])
          expect(mail.subject).to eq "Your impound claim was approved"
          expect(impound_claim.reload.response_message).to eq response_message
          # It escapes things - added '3D' in PR#2408 unclear why it was necessary
          expect(mail.body.encoded).to match "RESponse=3DMESSAGE&lt;alert&gt;"

          expect(response).to redirect_to review_impound_claim_path(impound_claim.id)
          expect(assigns(:impound_claim)).to eq impound_claim
          impound_record.reload
          expect(impound_record.status).to eq "current"
          expect(impound_record.update_kinds).to eq(ImpoundRecordUpdate.kinds - %w[move_location claim_approved claim_denied expired])
          expect(impound_record.impound_record_updates.count).to eq 1
          impound_record_update = impound_record.impound_record_updates.last
          expect(impound_record_update.user&.id).to eq current_user.id
          expect(impound_record_update.impound_claim&.id).to eq impound_claim.id
          expect(impound_record_update.kind).to eq "claim_approved"

          impound_claim.reload
          expect(impound_claim.status).to eq "approved"
          expect(impound_claim.notifications.pluck(:kind)).to match_array(%w[impound_claim_approved impound_claim_submitting])
          expect(impound_claim.impound_record_updates.pluck(:id)).to eq([impound_record_update.id])
          expect(impound_claim.response_message).to eq response_message
        end
      end
    end
    context "denied" do
      it "updates" do
        impound_record.reload
        expect(impound_record.impound_record_updates.count).to eq 0
        expect(impound_record.status).to eq "current"
        expect(impound_record.impound_claims.pluck(:id)).to eq([impound_claim.id])
        expect {
          patch "#{base_url}/#{impound_claim.to_param}", params: {
            submit: "Deny",
            impound_claim: {response_message: "I recommend talking with us about all the things"}
          }
        }.to change(EmailImpoundClaimJob.jobs, :count).by(1)
        expect(response).to redirect_to review_impound_claim_path(impound_claim.id)
        expect(assigns(:impound_claim)).to eq impound_claim
        impound_record.reload
        expect(impound_record.status).to eq "current"
        expect(impound_record.impound_record_updates.count).to eq 1
        impound_record_update = impound_record.impound_record_updates.last
        expect(impound_record_update.user&.id).to eq current_user.id
        expect(impound_record_update.impound_claim&.id).to eq impound_claim.id
        expect(impound_record_update.kind).to eq "claim_denied"

        impound_claim.reload
        expect(impound_claim.status).to eq "denied"
        expect(impound_claim.impound_record_updates.pluck(:id)).to eq([impound_record_update.id])
        expect(impound_claim.response_message).to eq "I recommend talking with us about all the things"
      end
    end
  end
end
