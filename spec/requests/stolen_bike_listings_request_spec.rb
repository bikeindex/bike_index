require "rails_helper"

RSpec.describe StolenBikeListingsController, type: :request do
  describe "theft-ring" do
    it "redirects to stolen_bike_listings" do
      get "/theft-rings"
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end
  describe "index" do
    let(:color) { FactoryBot.create(:color, name: "Blue") }
    let!(:stolen_bike_listing1) { FactoryBot.create(:stolen_bike_listing) }
    let!(:stolen_bike_listing2) { FactoryBot.create(:stolen_bike_listing, secondary_frame_color: color) }
    it "renders the index template with revised_layout" do
      expect(StolenBikeListing.pluck(:primary_frame_color_id)).to eq([Color.black.id, Color.black.id])
      get "/stolen_bike_listings"
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:stolen_bike_listings).pluck(:id)).to match_array([stolen_bike_listing1.id, stolen_bike_listing2.id])
      # And test that search works
      get "/stolen_bike_listings?query_items%5B%5D=#{Color.black.search_id}"
      expect(assigns(:stolen_bike_listings).pluck(:id)).to match_array([stolen_bike_listing1.id, stolen_bike_listing2.id])
      get "/stolen_bike_listings?query_items%5B%5D=#{color.search_id}"
      expect(assigns(:stolen_bike_listings).pluck(:id)).to eq([stolen_bike_listing2.id])
      get "/stolen_bike_listings?query_items%5B%5D=#{color.search_id}&query_items%5B%5D=#{Color.black.search_id}"
      expect(assigns(:stolen_bike_listings).pluck(:id)).to eq([stolen_bike_listing2.id])
    end
  end
end
