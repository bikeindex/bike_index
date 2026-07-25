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
