require "rails_helper"

RSpec.describe MarketplacePartnerShop, type: :model do
  describe "factory" do
    let(:marketplace_partner_shop) { FactoryBot.create(:marketplace_partner_shop) }

    it "starts pending, and books through us by default" do
      expect(marketplace_partner_shop).to be_valid
      expect(marketplace_partner_shop.status).to eq "pending"
      expect(marketplace_partner_shop.booked_by).to eq "bike_index_account"
      expect(marketplace_partner_shop.boxing_fee).to eq 75.0
    end
  end

  describe "organization_is_a_bike_shop" do
    let(:organization) { FactoryBot.create(:organization, kind: "bike_advocacy") }
    let(:marketplace_partner_shop) do
      FactoryBot.build(:marketplace_partner_shop, organization:, location: nil)
    end

    it "is invalid" do
      expect(marketplace_partner_shop).to_not be_valid
      expect(marketplace_partner_shop.errors.full_messages.join).to match(/bike shop/)
    end
  end

  describe "location_belongs_to_organization" do
    let(:marketplace_partner_shop) { FactoryBot.build(:marketplace_partner_shop, location:) }
    let(:location) { FactoryBot.create(:location) }

    it "won't take another organization's location" do
      expect(marketplace_partner_shop).to_not be_valid
      expect(marketplace_partner_shop.errors.full_messages.join).to match(/that shop's locations/)
    end
  end

  describe "enabled?" do
    let(:marketplace_partner_shop) do
      FactoryBot.create(:marketplace_partner_shop, :active, organization:)
    end

    context "organization without the feature" do
      let(:organization) { FactoryBot.create(:organization, kind: "bike_shop") }

      it "is active, but not enabled" do
        expect(marketplace_partner_shop.active?).to be_truthy
        expect(marketplace_partner_shop.enabled?).to be_falsey
      end
    end

    context "organization with the feature" do
      let(:organization) do
        FactoryBot.create(:organization_with_organization_features, kind: "bike_shop",
          enabled_feature_slugs: [described_class::FEATURE_SLUG])
      end

      it "is enabled" do
        expect(marketplace_partner_shop.enabled?).to be_truthy
      end

      context "paused" do
        let(:marketplace_partner_shop) do
          FactoryBot.create(:marketplace_partner_shop, status: "paused", organization:)
        end

        it "is not enabled - turning the shop off doesn't need the feature removed" do
          expect(marketplace_partner_shop.enabled?).to be_falsey
        end
      end
    end
  end

  describe "near" do
    let!(:marketplace_partner_shop) { FactoryBot.create(:marketplace_partner_shop, :accepting) }
    let(:location) { marketplace_partner_shop.location }
    let(:coordinates) { [location.latitude, location.longitude] }

    it "finds the shop by its location, and excludes the ones not taking drop-offs" do
      expect(described_class.near(coordinates).pluck(:id)).to eq([marketplace_partner_shop.id])

      marketplace_partner_shop.update(status: "paused")
      expect(described_class.near(coordinates).pluck(:id)).to eq([])
    end

    it "excludes an active shop whose organization doesn't have the feature" do
      without_feature = FactoryBot.create(:marketplace_partner_shop, :active)
      expect(without_feature.active?).to be_truthy
      expect(described_class.near(coordinates).pluck(:id)).to_not include(without_feature.id)
    end

    it "won't geocode a place name - that would be a blocking request inside a finder" do
      expect(described_class.near("New York, NY").pluck(:id)).to eq([])
    end

    it "doesn't find a shop across the country" do
      expect(described_class.near([45.52, -122.68]).pluck(:id)).to eq([])
    end
  end
end
