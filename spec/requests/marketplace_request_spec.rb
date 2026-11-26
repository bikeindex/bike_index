# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarketplaceController, type: :request do
  describe "how_it_works" do
    it "renders" do
      get "/marketplace/how-it-works"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("<title>How the Bike Index Marketplace works</title>")
      expect(response.body).to match(/id="buying"/)
      expect(response.body).to match(/id="selling"/)
      expect(response.body).to include(search_marketplace_path)
      # the badge the listing cards show
      expect(response.body).to include("Look for the Bike Index member badge.")
    end
  end
end
