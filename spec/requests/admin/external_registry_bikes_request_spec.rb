require "rails_helper"

RSpec.describe Admin::ExternalRegistryBikesController, type: :request do
  base_url = "/admin/external_registry_bikes"

  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    let!(:external_registry_bike) { FactoryBot.create(:external_registry_bike) }
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:bikes).pluck(:id)).to eq([external_registry_bike.id])
    end
  end
end
