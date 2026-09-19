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
      expect(bike_sticker_update.bike_sticker.bike_sticker_updates.count).to eq 2
      expect(assigns(:bike_sticker_updates).pluck(:id)).to match_array bike_sticker_update.bike_sticker.bike_sticker_updates.pluck(:id)

      # set_calculated_attributes always fills kind, so only legacy rows lack one
      bike_sticker_update.update_column(:kind, nil)
      get base_url, params: {render_chart: true}
      expect(response.status).to eq(200)
      expect(response.body).to include("no organization")
      # The grand total sums the rows, since the kind columns miss a kindless update
      expect(Nokogiri::HTML(response.body).css("tfoot td").last.text.strip).to eq "2"
    end
  end
end
