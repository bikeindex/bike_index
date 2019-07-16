require "rails_helper"

RSpec.describe Admin::ExportsController, type: :request do
  base_url = "/admin/exports"

  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end
end
