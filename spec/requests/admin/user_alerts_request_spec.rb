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
  end
end
