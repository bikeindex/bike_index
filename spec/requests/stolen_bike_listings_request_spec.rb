require "rails_helper"

RSpec.describe StolenBikeListingsController, type: :request do
  describe "theft-ring" do
    it "redirects to stolen_bike_listings" do
      get "/theft-ring"
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end
  describe "index" do
    it "renders the index template with revised_layout" do
      get "/stolen_bike_listings"
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end
end
