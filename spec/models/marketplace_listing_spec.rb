require "rails_helper"

RSpec.describe MarketplaceListing, type: :model do
  describe "factory" do
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing) }
    it "is valid" do
      expect(marketplace_listing).to be_valid
      expect(marketplace_listing.reload.id).to be_present
      expect(marketplace_listing.seller_id).to be_present
      expect(marketplace_listing.status).to eq "draft"
      expect(marketplace_listing.condition).to be_blank
    end
  end

  describe "find_or_build_current_for" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
    let(:user) { bike.user }

    it "returns a new marketplace_listing" do
      expect(bike.reload.current_ownership.user_id).to eq user.id
      marketplace_listing = MarketplaceListing.find_or_build_current_for(bike)
      expect(marketplace_listing).to be_valid
      expect(marketplace_listing.status).to eq "draft"
      expect(marketplace_listing.seller_id).to eq user.id
      expect(marketplace_listing.condition).to be_blank
    end
  end
end
