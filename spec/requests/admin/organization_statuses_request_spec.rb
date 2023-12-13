require "rails_helper"

RSpec.describe Admin::OrganizationStatusesController, type: :request do
  base_url = "/admin/organization_statuses"

  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    let!(:organization_status) { FactoryBot.create(:organization_status) }
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:organization_statuses).pluck(:id)).to eq([organization_status.id])
    end
  end
end
