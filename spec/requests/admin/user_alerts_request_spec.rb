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

    context "with an unfinished_registration" do
      let!(:b_param) do
        FactoryBot.create(:b_param, creator: FactoryBot.create(:user_confirmed),
          origin: "register_flow", params: {bike: {manufacturer_id: 1}})
      end

      it "links the b_param it alerts about" do
        get base_url

        expect(assigns(:collection).pluck(:kind)).to eq ["unfinished_registration"]
        expect(response.body).to include admin_b_param_path(b_param.id)
      end
    end

    context "with alerts" do
      let(:user_phone) { FactoryBot.create(:user_phone) }
      let(:theft_alert) { FactoryBot.create(:theft_alert) }
      let!(:phone_alert) do
        FactoryBot.create(:user_alert, kind: "phone_waiting_confirmation", alertable: user_phone)
      end
      # Written before alertable, so it renders off the legacy column
      let!(:legacy_theft_alert) do
        FactoryBot.create(:user_alert, kind: "theft_alert_without_photo", theft_alert:)
      end

      it "renders the alertable column" do
        get base_url
        expect(response.status).to eq(200)
        expect(assigns(:collection)).to match_array([phone_alert, legacy_theft_alert])
        expect(response.body).to match(admin_theft_alert_path(theft_alert.id))
        # UserPhone has no admin show page, admin_path_for_object links its user
        expect(response.body).to match(admin_user_path(user_phone.user_id))
      end
    end
  end
end
