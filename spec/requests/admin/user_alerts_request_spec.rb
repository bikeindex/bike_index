require "rails_helper"

base_url = "/admin/user_alerts"
RSpec.describe Admin::UserAlertsController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:collection)).to eq([])
    end

    context "with alerts" do
      let(:user_phone) { FactoryBot.create(:user_phone) }
      let(:promoted_alert) { FactoryBot.create(:promoted_alert) }
      let!(:phone_alert) do
        FactoryBot.create(:user_alert, kind: "phone_waiting_confirmation", alertable: user_phone)
      end
      let!(:promoted_alert_alert) do
        FactoryBot.create(:user_alert, kind: "theft_alert_without_photo", alertable: promoted_alert)
      end
      # after_commit creates its unfinished_registration alert
      let!(:b_param) do
        FactoryBot.create(:b_param, origin: "register_flow", params: {bike: {manufacturer_id: 1}})
      end

      it "renders the alertable column" do
        get base_url
        expect(response.status).to eq(200)
        expect(assigns(:collection).map(&:alertable)).to match_array([user_phone, promoted_alert, b_param])
        expect(response.body).to match(admin_theft_alert_path(promoted_alert.id))
        # UserPhone has no admin show page, admin_path_for_object links its user
        expect(response.body).to match(admin_user_path(user_phone.user_id))
        expect(response.body).to match(admin_b_param_path(b_param.id))
      end
    end
  end
end
