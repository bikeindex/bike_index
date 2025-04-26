require "rails_helper"

RSpec.describe MarketplaceListing, type: :model do
  it_behaves_like "address_recorded"

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

    def expect_new_marketplace_listing(passed_bike)
      marketplace_listing = MarketplaceListing.find_or_build_current_for(passed_bike)
      expect(marketplace_listing).to be_valid
      expect(marketplace_listing.status).to eq "draft"
      expect(marketplace_listing.seller_id).to eq user.id
      expect(marketplace_listing.condition).to eq "good"
      expect(marketplace_listing.id).to be_blank
      marketplace_listing
    end

    it "returns a new marketplace_listing" do
      expect(bike.reload.current_ownership.user_id).to eq user.id
      marketplace_listing = expect_new_marketplace_listing(bike)
      expect(marketplace_listing.address_record_id).to be_blank
    end

    context "with user with address record" do
      let!(:address_record) { FactoryBot.create(:address_record, user:) }
      before { user.update(address_record:) }

      it "returns with address_record_id" do
        expect(user.reload.address_record_id).to eq address_record.id
        marketplace_listing = expect_new_marketplace_listing(bike)
        expect(marketplace_listing.address_record_id).to eq address_record.id
      end
    end

    context "with marketplace_listing" do
      let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, item: bike, seller: user, status:) }
      let(:status) { "for_sale" }

      it "returns the current" do
        expect(bike.reload.marketplace_listings.pluck(:id)).to eq([marketplace_listing.id])
        expect(bike.reload.marketplace_listings.current.pluck(:id)).to eq([marketplace_listing.id])
        expect(MarketplaceListing.find_or_build_current_for(bike).id).to eq marketplace_listing.id
      end

      context "with status: removed" do
        let(:status) { "removed" }

        it "returns a new marketplace listing" do
          expect(bike.reload.marketplace_listings.pluck(:id)).to eq([marketplace_listing.id])
          expect(bike.reload.marketplace_listings.current.pluck(:id)).to eq([])
          expect_new_marketplace_listing(bike)
        end
      end
    end
  end

  describe "condition_humanized" do
    it "returns correct condition" do
      expect(MarketplaceListing.condition_humanized("new_in_box")).to eq "new in box"
    end

    it "has values for all conditions" do
      MarketplaceListing.conditions.keys.each do |condition|
        expect(MarketplaceListing.condition_humanized(condition)).to be_present
      end
    end
  end
end
