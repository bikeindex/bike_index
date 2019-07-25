require "rails_helper"

RSpec.describe Admin::BikeCodesController, type: :request do
  base_url = "/admin/bike_codes"

  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    let(:bike_code_batch) { FactoryBot.create(:bike_code_batch) }
    let!(:bike_code) { FactoryBot.create(:bike_code, bike_code_batch: bike_code_batch) }
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:bike_codes)).to eq([bike_code])
    end
    context "with search_query" do
      it "renders" do
        get base_url, search_query: "XXXXX"
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(assigns(:bike_codes)).to eq([])
      end
    end
  end
end
