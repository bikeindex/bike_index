require "rails_helper"

RSpec.describe TheftRingListingsController, type: :request do
  describe "index" do
    it "renders the index template with revised_layout" do
      get "/theft_ring_listings"
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end
end
