require "rails_helper"

RSpec.describe Admin::BikeStickersController, type: :request do
  base_url = "/admin/bike_stickers"

  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    let(:bike_sticker_batch) { FactoryBot.create(:bike_sticker_batch) }
    let!(:bike_sticker) { FactoryBot.create(:bike_sticker, bike_sticker_batch: bike_sticker_batch) }
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:bike_stickers)).to eq([bike_sticker])
    end
    context "with search_query" do
      it "renders" do
        get base_url, params: { search_query: "XXXXX" }
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(assigns(:bike_stickers)).to eq([])
      end
    end
  end
end
