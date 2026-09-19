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

  describe "show" do
    let!(:impound_record) { FactoryBot.create(:impound_record) }
    it "renders" do
      get "#{base_url}/pkey-#{impound_record.id}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
      expect(assigns(:impound_record).id).to eq impound_record.id
      # It works with just the bare ID too
      get "#{base_url}/#{impound_record.id}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
      expect(assigns(:impound_record).id).to eq impound_record.id
    end
  end
end
