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
  end
end
