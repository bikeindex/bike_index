require "rails_helper"

RSpec.describe StolenBikeListingsController, type: :request do
  describe "index" do
    it "renders the index template with revised_layout" do
      get "/stolen_bike_listings"
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end
end
