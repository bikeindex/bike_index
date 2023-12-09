require "rails_helper"

RSpec.describe Admin::PosIntegrationStatusesController, type: :request do
  base_url = "/admin/pos_integration_statuses"

  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    let!(:pos_integration_status) { FactoryBot.create(:pos_integration_status) }
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:pos_integration_statuses).pluck(:id)).to eq([pos_integration_status.id])
    end
  end
end
