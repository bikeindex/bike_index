# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::MarketplaceListingCard::Component, type: :component do
  let(:bike) { marketplace_listing.item.reload }
  let(:current_user) { nil }
  let(:owner) { false }
  let(:preview) { false }
  let(:component) { render_inline(described_class.new(bike:, current_user:, owner:, preview:, term: :right_align)) }

  context "with a draft listing" do
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing) }

    it "doesn't render" do
      expect(bike.is_for_sale?).to be false
      expect(component.to_html).to be_blank
    end

    context "preview" do
      let(:preview) { true }

      it "renders the draft, without the contact link" do
        expect(component.text).to include("is for sale")
        expect(component.text).to include("excellent")
        expect(component).to_not have_link("Contact the seller")
      end
    end
  end

  context "with a listing for sale" do
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale) }

    it "renders the listing and a link to contact the seller" do
      expect(bike.is_for_sale?).to be true
      expect(component.text).to include("excellent")
      expect(component.text).to include("lightly ridden")
      expect(component.text).to include("is for sale")
      expect(component.text).to_not include("Bike Index member")
      expect(component).to have_link("Contact the seller", href: "/my_account/messages/ml_#{marketplace_listing.id}")
    end

    context "when viewed as the owner" do
      let(:owner) { true }

      it "renders without the contact link" do
        expect(component.text).to include("is for sale")
        expect(component).to_not have_link("Contact the seller")
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
end
