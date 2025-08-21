# == Schema Information
#
# Table name: marketplace_listings
#
#  id                :bigint           not null, primary key
#  amount_cents      :integer
#  condition         :integer
#  currency_enum     :integer
#  description       :text
#  end_at            :datetime
#  item_type         :string
#  latitude          :float
#  longitude         :float
#  price_negotiable  :boolean          default(FALSE)
#  published_at      :datetime
#  status            :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  address_record_id :bigint
#  buyer_id          :bigint
#  item_id           :bigint
#  seller_id         :bigint
#
# Indexes
#
#  index_marketplace_listings_on_address_record_id  (address_record_id)
#  index_marketplace_listings_on_buyer_id           (buyer_id)
#  index_marketplace_listings_on_item               (item_type,item_id)
#  index_marketplace_listings_on_seller_id          (seller_id)
#
require "rails_helper"

RSpec.describe MarketplaceListing, type: :model do
  it_behaves_like "address_recorded"
  it_behaves_like "amountable"

  describe "factory" do
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing) }

    it "is valid" do
      expect(marketplace_listing).to be_valid
      expect(marketplace_listing.reload.id).to be_present
      expect(marketplace_listing.seller_id).to be_present
      expect(marketplace_listing.status).to eq "draft"
    end
    context "passed just bike" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
      let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, item: bike) }
      it "uses bike user" do
        expect(bike.reload.user&.id).to be_present
        expect(marketplace_listing.seller_id).to eq bike.user.id
        expect(marketplace_listing.just_failed_to_publish?).to be_falsey
        expect(bike.current_event_record&.id).to be_blank
      end

      context "for sale" do
        let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale) }
        let(:bike) { marketplace_listing.item }
        it "includes marketplace_listing" do
          expect(marketplace_listing.valid_publishable?).to be_truthy
          expect(marketplace_listing.just_published?).to be_truthy
          expect(marketplace_listing.just_failed_to_publish?).to be_falsey
          expect(bike.current_event_record&.id).to eq marketplace_listing.id
          expect(bike.reload.is_for_sale).to be_truthy
        end
      end
    end
    context "sold" do
      let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :sold) }
      it "is valid" do
        expect(marketplace_listing.reload.status).to eq "sold"
        expect(marketplace_listing.published_at).to be_present
        expect(marketplace_listing.end_at).to be_present
        expect(marketplace_listing.buyer).to be_present
      end
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
      expect(marketplace_listing.amount_cents).to be_blank
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
      expect(MarketplaceListing.condition_humanized("new_in_box")).to eq "new"
      expect(MarketplaceListing.condition_description_humanized("new_in_box")).to eq "unridden/with tags"
      expect(MarketplaceListing.condition_with_description_humanized("new_in_box")).to eq "new - unridden/with tags"
    end

    it "has values for all conditions" do
      MarketplaceListing.conditions.keys.each do |condition|
        expect(MarketplaceListing.condition_humanized(condition)).to be_present
        expect(MarketplaceListing.condition_description_humanized(condition)).to be_present
        expect(MarketplaceListing.condition_with_description_humanized(condition)).to be_present
      end
    end
  end

  describe "search" do
    let!(:marketplace_listing_low) { FactoryBot.create(:marketplace_listing, :for_sale, amount_cents: 10_00) }
    let!(:marketplace_listing_mid) { FactoryBot.create(:marketplace_listing, amount_cents: 100_00) }
    let!(:marketplace_listing_high) { FactoryBot.create(:marketplace_listing, :for_sale, amount_cents: 1000_00) }
    let(:item_low_id) { marketplace_listing_low.item_id }
    let(:item_mid_id) { marketplace_listing_mid.item_id }
    let(:item_high_id) { marketplace_listing_high.item_id }
    let(:item_ids) { [item_low_id, item_mid_id, item_high_id] }

    def expect_target_search_results
      expect(MarketplaceListing.search(Bike).pluck(:id).sort).to eq item_ids
      expect(MarketplaceListing.search(Bike, price_min_amount: 99).pluck(:id).sort).to eq([item_mid_id, item_high_id])
      expect(MarketplaceListing.search(Bike, price_max_amount: 500).pluck(:id).sort).to eq([item_low_id, item_mid_id])
      expect(MarketplaceListing.search(Bike, price_min_amount: 99, price_max_amount: 5000).pluck(:id).sort)
        .to eq([item_mid_id, item_high_id])
      expect(MarketplaceListing.search(Bike, price_min_amount: 10.1, price_max_amount: 999).pluck(:id).sort)
        .to eq([item_mid_id])
    end

    it "searches" do
      expect(Bike.pluck(:id).sort).to eq item_ids
      expect(Bike.all.map(&:current_marketplace_listing).compact.map(&:id).sort)
        .to eq([marketplace_listing_low.id, marketplace_listing_mid.id, marketplace_listing_high.id])

      expect_target_search_results
    end

    context "with a sold listing" do
      let!(:marketplace_listing_previous) { FactoryBot.create(:marketplace_listing, :sold, item: marketplace_listing_low.item, end_at: Time.current - 3.days) }
      let!(:marketplace_listing_sold) { FactoryBot.create(:marketplace_listing, :sold) }
      let(:item_sold_id) { marketplace_listing_sold.item_id }
      let(:item_ids) { [item_low_id, item_mid_id, item_high_id, item_sold_id] }

      it "searches" do
        expect(Bike.pluck(:id).sort).to eq item_ids
        expect(Bike.all.map(&:current_marketplace_listing).compact.map(&:id).sort)
          .to eq([marketplace_listing_low.id, marketplace_listing_mid.id, marketplace_listing_high.id])

        expect_target_search_results
      end
    end
  end

  describe "validate_publishable!" do
    let(:user_hidden) { false }
    let(:primary_activity) { FactoryBot.create(:primary_activity) }
    let(:item) { FactoryBot.create(:bike, :with_ownership_claimed, user_hidden:, cycle_type: :stroller, primary_activity:) }
    let(:user) { item.user }
    let(:address_record) { FactoryBot.create(:address_record, user:, kind: :user) }
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, item:, address_record:, condition: "poor") }

    it "is truthy" do
      expect(marketplace_listing.validate_publishable!).to be_truthy
      expect(marketplace_listing.errors.full_messages).to eq([])
    end

    context "no price" do
      it "is false" do
        marketplace_listing.amount_cents = nil
        expect(marketplace_listing.validate_publishable!).to be_falsey
        expect(marketplace_listing.errors.full_messages).to eq(["Price is required"])
      end
    end
    context "user hidden" do
      let(:user_hidden) { true }
      it "is false when item is missing" do
        expect(item.reload.current?).to be_falsey
        expect(marketplace_listing.validate_publishable!).to be_falsey
        expect(marketplace_listing.errors.full_messages).to eq(["Stroller is not visible - maybe you marked it hidden?"])
      end
    end
  end

  describe "visible_by?" do
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing) }
    it "is visible by the user" do
      expect(marketplace_listing.visible_by?).to be_falsey
      expect(marketplace_listing.visible_by?(marketplace_listing.seller)).to be_truthy
    end
  end

  describe "publishing" do
    let(:primary_activity_id) { FactoryBot.create(:primary_activity).id }
    let(:marketplace_listing) do
      FactoryBot.build(:marketplace_listing, :for_sale, item:, published_at: nil, primary_activity_id:)
    end
    let(:item) { FactoryBot.create(:bike) }

    it "assigns published_at, then removes when marked draft" do
      expect(item.reload.is_for_sale).to be_falsey
      expect(item.primary_activity_id).to be_blank
      expect(marketplace_listing.published_at).to be_blank
      expect(marketplace_listing.save).to be_truthy
      expect(marketplace_listing.just_published?).to be_truthy
      expect(marketplace_listing.published_at).to be_within(1).of Time.current
      expect(item.reload.is_for_sale).to be_truthy
      marketplace_listing.validate_publishable!
      expect(marketplace_listing.errors.full_messages).to be_blank
      # Marking draft again makes it not for sale
      marketplace_listing.update(status: "draft")
      expect(marketplace_listing.reload.published_at).to be_nil
      expect(item.reload.is_for_sale).to be_falsey
    end

    context "with not valid publishable" do
      let(:primary_activity_id) { nil }

      it "is saves, but as draft" do
        expect(marketplace_listing.status).to eq "for_sale"
        expect(marketplace_listing.save).to be_truthy
        expect(marketplace_listing.just_published?).to be_falsey
        expect(marketplace_listing.just_failed_to_publish?).to be_truthy
        expect(marketplace_listing.id).to be_present
        expect(marketplace_listing.status).to eq "draft"
        expect(marketplace_listing.published_at).to be_nil

        expect(item.reload.is_for_sale).to be_falsey
        marketplace_listing.validate_publishable!
        expect(marketplace_listing.errors.full_messages).to be_present
      end
    end

    context "updating with not valid for sale params" do
      it "saves but marks draft" do
        expect(marketplace_listing.save).to be_truthy
        expect(marketplace_listing.status).to eq "for_sale"
        expect(marketplace_listing.update(amount_with_nil: nil)).to be_truthy
        expect(marketplace_listing.reload.amount_cents).to be_nil
        expect(marketplace_listing.status).to eq "draft"
        expect(marketplace_listing.valid_publishable?).to be_falsey
      end
    end
  end
end
