require "rails_helper"

RSpec.describe MarketplaceOrder, type: :model do
  it_behaves_like "amountable"

  describe "factory" do
    let(:marketplace_order) { FactoryBot.create(:marketplace_order) }

    it "is valid, and takes the seller and price from the listing" do
      expect(marketplace_order).to be_valid
      expect(marketplace_order.status).to eq "pending_payment"
      expect(marketplace_order.seller_id).to eq marketplace_order.marketplace_listing.seller_id
      expect(marketplace_order.item_amount_cents)
        .to eq marketplace_order.marketplace_listing.amount_cents
      expect(marketplace_order).to_not be_ended
    end
  end

  describe "amount_cents" do
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale, amount_cents: 120_000) }
    let(:marketplace_order) do
      FactoryBot.create(:marketplace_order, :shipped, marketplace_listing:, platform_fee_cents: 1_000)
    end

    it "totals what the buyer is charged" do
      expect(marketplace_order.amount_cents).to eq(120_000 + 9_250 + 7_500 + 1_000)
      expect(marketplace_order.fulfillment_amount_cents).to eq(9_250 + 7_500)
    end

    context "local pickup" do
      let(:marketplace_order) { FactoryBot.create(:marketplace_order, marketplace_listing:) }

      it "is only the bike" do
        expect(marketplace_order.amount_cents).to eq 120_000
        expect(marketplace_order.fulfillment_amount_cents).to eq 0
      end
    end

    # a refund adjusts the components; it mustn't rewrite what the buyer was actually charged
    context "already paid" do
      let(:marketplace_order) do
        FactoryBot.create(:marketplace_order, :paid, marketplace_listing:)
      end

      it "doesn't recalculate" do
        expect(marketplace_order.amount_cents).to eq 120_000

        marketplace_order.update(item_amount_cents: 60_000)
        expect(marketplace_order.reload.amount_cents).to eq 120_000
      end
    end
  end

  describe "buyer_is_not_seller" do
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale) }
    let(:marketplace_order) do
      FactoryBot.build(:marketplace_order, marketplace_listing:, buyer: marketplace_listing.seller)
    end

    it "is invalid" do
      expect(marketplace_order).to_not be_valid
      expect(marketplace_order.errors.full_messages.join).to match(/own listing/)
    end
  end

  describe "fulfillment_is_available" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, propulsion_type: "throttle") }
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, item: bike) }
    let(:marketplace_order) { FactoryBot.build(:marketplace_order, :shipped, marketplace_listing:) }

    it "can't ship a listing that isn't shippable" do
      expect(marketplace_listing.shippable?).to be_falsey
      expect(marketplace_order).to_not be_valid
      expect(marketplace_order.errors.full_messages.join).to match(/isn't available/)
    end

    context "local pickup" do
      let(:marketplace_order) { FactoryBot.build(:marketplace_order, marketplace_listing:) }

      it "is valid - an e-bike still sells locally" do
        expect(marketplace_order).to be_valid
      end
    end
  end

  describe "status_matches_fulfillment_kind" do
    let(:marketplace_order) { FactoryBot.create(:marketplace_order) }

    # Only the one error - a local pickup should never be told it's missing a shop
    it "can't put a local pickup into a shipping status" do
      expect(marketplace_order.update(status: "in_transit")).to be_falsey
      expect(marketplace_order.errors.full_messages.count).to eq 1
      expect(marketplace_order.errors.full_messages.join).to match(/local pickup/)
    end

    it "still completes" do
      expect(marketplace_order.update(status: "completed")).to be_truthy
      expect(marketplace_order.reload).to be_ended
    end
  end

  describe "shop_present_once_shipping_starts" do
    let(:marketplace_order) { FactoryBot.create(:marketplace_order, :shipped) }
    let(:marketplace_partner_shop) { FactoryBot.create(:marketplace_partner_shop, :active) }

    it "can't await a drop-off at a shop nobody named" do
      expect(marketplace_order.update(status: "awaiting_drop_off")).to be_falsey
      expect(marketplace_order.errors.full_messages.join).to match(/before a shipment starts/)

      expect(marketplace_order.update(status: "awaiting_drop_off", marketplace_partner_shop:))
        .to be_truthy
      expect(marketplace_partner_shop.reload.marketplace_orders.pluck(:id))
        .to eq([marketplace_order.id])
    end

    it "still cancels without one" do
      expect(marketplace_order.update(status: "cancelled")).to be_truthy
    end
  end

  describe "current" do
    let!(:marketplace_order) { FactoryBot.create(:marketplace_order) }
    let!(:cancelled) { FactoryBot.create(:marketplace_order, status: "cancelled") }

    it "excludes the ended ones" do
      expect(described_class.current.pluck(:id)).to eq([marketplace_order.id])
    end
  end
end
