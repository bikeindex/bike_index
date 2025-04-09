require "rails_helper"

RSpec.describe MarketplaceListing, type: :model do
  describe "factory" do
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing) }
    it "is valid" do
      expect(marketplace_listing).to be_valid
      expect(marketplace_listing.reload.id).to be_present
      expect(marketplace_listing.seller_id).to be_present
      expect(marketplace_listing.status).to eq "draft"
    end
  end
end
