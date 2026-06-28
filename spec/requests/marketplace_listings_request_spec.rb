require "rails_helper"

RSpec.describe MarketplaceListingsController, type: :request do
  describe "show" do
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, id: 35) }
    it "redirects to the item from the /m/ short URL" do
      expect(marketplace_listing.short_id).to eq "m/Z"
      ["/m/z", "/M/Z", "/m/Z"].each do |path|
        get path
        expect(response).to redirect_to(marketplace_listing.item)
      end
    end
  end
end
