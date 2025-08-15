require "rails_helper"

RSpec.describe Organized::ImpoundClaimsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/impound_claims" }
  include_context :request_spec_logged_in_as_organization_user

  let(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: enabled_feature_slugs) }
  let(:user_email) { "someemail@things.com" }
  let(:user_claiming) { FactoryBot.create(:user_confirmed, email: user_email) }
  let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, :with_stolen_record, user: user_claiming) }
  let(:enabled_feature_slugs) { %w[parking_notifications impound_bikes] }
  let(:impound_record) { FactoryBot.create(:impound_record_with_organization, organization: current_organization, user: current_user, bike: bike, display_id: 1111) }
  let(:impound_claim) { FactoryBot.create(:impound_claim, impound_record: impound_record, stolen_record: bike.current_stolen_record, status: status) }
  let(:status) { "submitting" }

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:impound_claims).count).to eq 0
    end
    context "multiple impound_records" do
      let(:bike2) { FactoryBot.create(:bike, serial_number: "yaris") }
      let!(:impound_claim2) { FactoryBot.create(:impound_claim_with_stolen_record, organization: current_organization, user: current_user, bike: bike2, status: "submitting") }
      let!(:impound_claim_approved) { FactoryBot.create(:impound_claim, organization: current_organization, status: "approved") }
      let!(:impound_claim_resolved) { FactoryBot.create(:impound_claim_resolved, organization: current_organization) }
      let!(:impound_claim_unorganized) { FactoryBot.create(:impound_claim) }
      it "finds by impound scoping" do
        impound_claim.reload
        expect(impound_claim.bike_submitting&.id).to eq bike.id
        expect(impound_claim.bike_claimed&.id).to eq bike.id
        expect(impound_claim.active?).to be_truthy
        expect(impound_claim.organization_id).to eq current_organization.id
        impound_claim2.reload
        expect(impound_claim2.active?).to be_truthy
        expect(impound_claim2.organization_id).to eq current_organization.id
        impound_claim_approved.reload
        expect(impound_claim_approved.active?).to be_truthy
        expect(impound_claim_approved.organization_id).to eq current_organization.id
        # Test that impound_claim.active.bikes scopes correctly
        active_ids = [impound_claim.id, impound_claim2.id, impound_claim_approved.id]
        expect(current_organization.impound_claims.active.pluck(:id)).to match_array(active_ids)
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(assigns(:search_status)).to eq "active"
        expect(assigns(:impound_claims).pluck(:id)).to match_array(active_ids)

        get "#{base_url}?search_status=all"
        expect(response.status).to eq(200)
        expect(assigns(:search_status)).to eq "all"
        expect(assigns(:impound_claims).pluck(:id)).to match_array(active_ids + [impound_claim_resolved.id])

        get "#{base_url}?search_impound_record_id=#{impound_record.id}"
        expect(response.status).to eq(200)
        expect(assigns(:impound_claims).pluck(:id)).to match_array([impound_claim.id])
      end
    end
  end

  describe "show" do
    it "renders" do
      impound_claim.reload
      get "#{base_url}/#{impound_claim.to_param}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
      expect(assigns(:impound_claim)).to eq impound_claim
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
      }.to_not change(Email::ImpoundClaimJob.jobs, :count)
      expect(flash[:error]).to be_present
      expect(response).to redirect_to organization_impound_claim_path(impound_claim.id, organization_id: current_organization.id)
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
        }.to change(Email::ImpoundClaimJob.jobs, :count).by(1)
        expect(response).to redirect_to organization_impound_claim_path(impound_claim.id, organization_id: current_organization.id)
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
        let(:snippet_body) { "<p>claim-approved-snippet</p>" }
        let(:response_message) { "RESponse=MESSAGE<alert>" }
        it "sends a message" do
          FactoryBot.create(:organization_mail_snippet, kind: "impound_claim_approved", organization: current_organization, body: snippet_body)
          Email::ImpoundClaimJob.new.perform(impound_claim.id)
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
          expect(mail.reply_to).to eq([current_organization.auto_user.email])
          expect(mail.subject).to eq "Your impound claim was approved"
          expect(mail.body.encoded).to match snippet_body
          # It escapes things - added '3D' in PR#2408 unclear why it was necessary
          expect(mail.body.encoded).to match "RESponse=3DMESSAGE&lt;alert&gt;"

          expect(response).to redirect_to organization_impound_claim_path(impound_claim.id, organization_id: current_organization.id)
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
        }.to change(Email::ImpoundClaimJob.jobs, :count).by(1)
        expect(response).to redirect_to organization_impound_claim_path(impound_claim.id, organization_id: current_organization.id)
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
