require "rails_helper"

RSpec.describe Admin::BikeStickerUpdatesController, type: :request do
  base_url = "/admin/bike_sticker_updates"

  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    let!(:bike_sticker_update) { FactoryBot.create(:bike_sticker_update) }
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:bike_sticker_updates)).to eq([bike_sticker_update])
    end
  end
end
