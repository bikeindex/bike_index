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
    let(:stolen_record) { FactoryBot.create(:stolen_record, can_share_recovery: true) }
    let(:params) { { stolen_record: { recovery_display_status: true } } }
    it "can change waiting_on_decision to not_displayed" do
      put :update, id: stolen_record.id, params: params
      expect(stolen_record.recovery_display_status).to eq "not_displayed"
    end
  end
end
