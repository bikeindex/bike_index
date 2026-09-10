# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::MarketplaceListingPanel::Component, type: :component do
  let(:options) { {marketplace_listing:} }
  let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale) }
  let(:component) { render_inline(described_class.new(**options)) }

  it "renders without the member badge for a non-member seller" do
    expect(marketplace_listing.seller_member?).to be false
    expect(component).to be_present
    expect(component.text).to_not include("Bike Index member")
  end

  describe "shipping" do
    it "says a standard bike can ship, with no reason to explain" do
      expect(component.text).to include("Can be shipped")
      expect(component.text).to_not include("hazardous")
    end

    context "motorized" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, propulsion_type: "throttle") }
      let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale, item: bike) }

      it "says local pickup only, and names the cycle type in lowercase" do
        expect(component.text).to include("Local pickup only")
        expect(component.text).to match(/a motorized bike can't be shipped/)
      end
    end

    context "a cycle type we don't ship" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, cycle_type: :cargo) }
      let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale, item: bike) }

      it "says we can't ship it yet, rather than blaming a battery it doesn't have" do
        expect(component.text).to include("Local pickup only")
        expect(component.text).to match(/can't ship a cargo bike yet/)
        expect(component.text).to_not include("hazardous")
      end
    end
  end

  context "when the seller is a member" do
    let(:seller) { FactoryBot.create(:user, :with_address_record, address_in: :davis) }
    let!(:membership) { FactoryBot.create(:membership, user: seller) }
    let(:marketplace_listing) do
      FactoryBot.create(:marketplace_listing, :for_sale, address_record: seller.address_record, seller:)
    end

    it "renders the member badge" do
      expect(marketplace_listing.seller_member?).to be true
      expect(component.text).to include("Bike Index member")
    end
  end
end
