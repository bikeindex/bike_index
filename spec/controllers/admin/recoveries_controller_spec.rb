require "rails_helper"

RSpec.describe Admin::RecoveriesController, type: :controller do
  include_context :logged_in_as_super_admin
  describe "index" do
    it "renders" do
      get :index
      expect(response).to be_success
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
    end
  end
  describe "update" do
    context "admin marks recovery as undisplayable" do
      let(:stolen_record) { FactoryBot.create(:stolen_record, can_share_recovery: true, recovery_display_status: "waiting_on_decision") }
      let(:params) { { id: stolen_record.id, stolen_record: { is_not_displayable: true } } }
      it "updates waiting_on_decision to not_displayed" do
        expect do
          put :update, params
        end.to change(RecoveryDisplay, :count).by 0
        stolen_record.reload
        expect(stolen_record.recovery_display_status).to eq "not_displayed"
        expect(response).to redirect_to(admin_recoveries_path)
        expect(flash).to be_present
      end
    end
    context "admin marks recovery as can_share_recovery" do
      let(:stolen_record) { FactoryBot.create(:stolen_record, can_share_recovery: true, recovery_display_status: "not_eligible") }
      let(:params) { { id: stolen_record.id, stolen_record: { can_share_recovery: true } } }
      it "updates can_share_recovery" do
        expect do
          put :update, params
        end.to change(RecoveryDisplay, :count).by 0
        stolen_record.reload
        expect(stolen_record.can_share_recovery).to be_truthy
        expect(response).to redirect_to(admin_recoveries_path)
        expect(flash).to be_present
      end
    end
    context "admin marks recovery as index_helped_recover" do
      let(:stolen_record) { FactoryBot.create(:stolen_record, can_share_recovery: true, recovery_display_status: "not_eligible") }
      let(:params) { { id: stolen_record.id, stolen_record: { index_helped_recovery: true } } }
      it "updates index_helped_recover" do
        expect do
          put :update, params
        end.to change(RecoveryDisplay, :count).by 0
        stolen_record.reload
        expect(stolen_record.index_helped_recovery).to be_truthy
        expect(response).to redirect_to(admin_recoveries_path)
        expect(flash).to be_present
      end
    end
    context "admin marks undisplayable bike as displayable" do
      let!(:public_image) { FactoryBot.create(:public_image, imageable: bike) }
      let(:stolen_record) { FactoryBot.create(:stolen_record, can_share_recovery: true, recovery_display_status: "not_displayed") }
      let(:bike) { stolen_record.bike }
      let(:params) { { id: stolen_record.id, stolen_record: { mark_as_eligible: true } } }
      it "updates not_displayed to waiting_on_decision" do
        bike.reload.update_attributes(updated_at: Time.current)
        stolen_record.reload.update_attributes(updated_at: Time.current)
        expect do
          put :update, params
        end.to change(RecoveryDisplay, :count).by 0
        stolen_record.reload
        expect(stolen_record.recovery_display_status).to eq "waiting_on_decision"
        expect(response).to redirect_to(new_admin_recovery_display_path(stolen_record))
        expect(flash).to be_present
      end
    end
  end
end
