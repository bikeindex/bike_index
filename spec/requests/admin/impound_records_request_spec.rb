require "rails_helper"

base_url = "/admin/impound_records"
RSpec.describe Admin::ImpoundRecordsController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    let!(:impound_record) { FactoryBot.create(:impound_record) }
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:impound_records)).to eq([impound_record])
    end
  end
end
