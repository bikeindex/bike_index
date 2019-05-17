require "spec_helper"

base_url = "/admin/bike_codes"

describe "Admin::ExportsController" do
  # Request specs don't have cookies so we need to stub stuff if we're in request specs
  # This is suboptimal, but hey, it gets us to request specs for now
  before { allow(User).to receive(:from_auth) { user } }
  let(:user) { FactoryBot.create(:admin) }

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
