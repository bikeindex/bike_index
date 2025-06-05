require "rails_helper"

RSpec.describe MarketplaceController, type: :request do
  let(:base_url) { "/marketplace" }

  describe "index" do
    it "renders" do
      get base_url
      expect(flash).to be_blank
      expect(response).to render_template("index")
      expect(assigns(:marketplace_listings).pluck(:id)).to eq([])
    end

    context "with a marketplace_listing" do
      let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale) }

      it "renders" do
        get base_url
        expect(flash).to be_blank
        expect(response).to render_template("index")
        expect(assigns(:marketplace_listings).pluck(:id)).to eq([marketplace_listing.id])
      end
    end
  end
end
