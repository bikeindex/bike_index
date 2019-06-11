require "spec_helper"

describe Admin::RecoveriesController do
  describe "index" do
    it "renders" do
      user = FactoryBot.create(:admin)
      set_current_user(user)
      get :index
      expect(response).to be_success
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
    end
  end
  describe "update" do
    context "admin marks recovery that as undisplayable" do
      let(:stolen_record) { FactoryBot.create(:stolen_record, can_share_recovery: true, recovery_display_status: "waiting_on_decision") }
      let(:params) { { id: stolen_record.id, stolen_record: { index_helped_recovery: 1, can_share_recovery: 1 }, is_not_displayable: { undisplayable: 1 } } }
      it "updates waiting_on_decision to not_displayed" do
        user = FactoryBot.create(:admin)
        set_current_user(user)
        put :update, params
        stolen_record.reload
        expect(stolen_record.recovery_display_status).to eq "not_displayed"
      end
    end
    context "admin marks undisplayable bike as displayable" do
      let!(:public_image) { FactoryBot.create(:public_image, imageable: bike) }
      let(:stolen_record) { FactoryBot.create(:stolen_record, can_share_recovery: true, recovery_display_status: "waiting_on_decision") }
      let(:bike) { stolen_record.bike }
      let(:params) { { id: stolen_record.id, stolen_record: { index_helped_recovery: 1, can_share_recovery: 1 }, mark_as_eligible: { eligible: 1 } } }
      it "updates not_displayed to waiting_on_decision" do
        user = FactoryBot.create(:admin)
        set_current_user(user)
        bike.reload.update_attributes(updated_at: Time.now)
        stolen_record.reload.update_attributes(updated_at: Time.now)
        put :update, params
        stolen_record.reload
        expect(stolen_record.recovery_display_status).to eq "waiting_on_decision"
      end
    end
  end
end
