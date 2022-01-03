require "rails_helper"

base_url = "/admin/recoveries"
RSpec.describe Admin::RecoveriesController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    it "renders" do
      get base_url
      expect(response).to be_ok
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
      # Added in #2137 because there was an error in the scope
      get "#{base_url}?search_displayed=displayed&search_shareable=true"
      expect(response).to be_ok
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
    end
  end
  describe "edit" do
    let(:stolen_record) { bike.current_stolen_record }
    let(:bike) { FactoryBot.create(:bike, :with_stolen_record, :with_ownership) }
    it "doesn't break if recovery's bike is deleted" do
      expect(stolen_record).to be_present
      bike.destroy
      get "#{base_url}/#{stolen_record.id}/edit"
      expect(response).to be_ok
      expect(flash).to_not be_present
    end
  end
  describe "update" do
    context "admin marks recovery as undisplayable" do
      let(:stolen_record) { FactoryBot.create(:stolen_record, can_share_recovery: true, recovery_display_status: "waiting_on_decision") }
      let(:params) { {id: stolen_record.id, stolen_record: {is_not_displayable: true}} }
      it "updates waiting_on_decision to not_displayed" do
        expect {
          put "#{base_url}/#{stolen_record.id}", params: params
        }.to change(RecoveryDisplay, :count).by 0
        stolen_record.reload
        expect(stolen_record.recovery_display_status).to eq "not_displayed"
        expect(response).to redirect_to(admin_recoveries_path)
        expect(flash).to be_present
      end
      context "bike deleted" do
        it "updates waiting_on_decision to not_displayed" do
          stolen_record.bike.update(user_hidden: true)
          expect {
            put "#{base_url}/#{stolen_record.id}", params: params
          }.to change(RecoveryDisplay, :count).by 0
          stolen_record.reload
          expect(stolen_record.recovery_display_status).to eq "not_displayed"
          expect(response).to redirect_to(admin_recoveries_path)
          expect(flash).to be_present
        end
      end
    end
    context "admin marks recovery as can_share_recovery" do
      let(:stolen_record) { FactoryBot.create(:stolen_record, can_share_recovery: true, recovery_display_status: "not_eligible") }
      let(:params) { {id: stolen_record.id, stolen_record: {can_share_recovery: true}} }
      it "updates can_share_recovery" do
        expect {
          put "#{base_url}/#{stolen_record.id}", params: params
        }.to change(RecoveryDisplay, :count).by 0
        stolen_record.reload
        expect(stolen_record.can_share_recovery).to be_truthy
        expect(response).to redirect_to(admin_recoveries_path)
        expect(flash).to be_present
      end
    end
    context "admin marks recovery as index_helped_recover" do
      let(:stolen_record) { FactoryBot.create(:stolen_record, can_share_recovery: true, recovery_display_status: "not_eligible") }
      let(:params) { {id: stolen_record.id, stolen_record: {index_helped_recovery: true}} }
      it "updates index_helped_recover" do
        expect {
          put "#{base_url}/#{stolen_record.id}", params: params
        }.to change(RecoveryDisplay, :count).by 0
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
      let(:params) { {id: stolen_record.id, stolen_record: {mark_as_eligible: true}} }
      it "updates not_displayed to waiting_on_decision" do
        bike.reload.update(updated_at: Time.current)
        stolen_record.reload.update(updated_at: Time.current)
        expect {
          put "#{base_url}/#{stolen_record.id}", params: params
        }.to change(RecoveryDisplay, :count).by 0
        stolen_record.reload
        expect(stolen_record.recovery_display_status).to eq "waiting_on_decision"
        expect(response).to redirect_to(new_admin_recovery_display_path(stolen_record))
        expect(flash).to be_present
      end
    end
  end
end
