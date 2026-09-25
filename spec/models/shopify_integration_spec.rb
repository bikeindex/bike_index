require "rails_helper"

RSpec.describe ShopifyIntegration, type: :model do
  describe "normalize_shop_domain" do
    # Merchants type whatever they call their store; Shopify only ever sends the myshopify host
    it "reduces what a merchant might type to the myshopify host" do
      expect(described_class.normalize_shop_domain("cool-bikes")).to eq "cool-bikes.myshopify.com"
      expect(described_class.normalize_shop_domain("cool-bikes.myshopify.com")).to eq "cool-bikes.myshopify.com"
      expect(described_class.normalize_shop_domain("https://cool-bikes.myshopify.com/")).to eq "cool-bikes.myshopify.com"
      expect(described_class.normalize_shop_domain(" COOL-BIKES.myshopify.com ")).to eq "cool-bikes.myshopify.com"
      expect(described_class.normalize_shop_domain(nil)).to be_nil
      expect(described_class.normalize_shop_domain(" ")).to be_nil
    end

    # It's the URL in a merchant's address bar, and its host names no store
    it "takes the store out of an admin URL" do
      expect(described_class.normalize_shop_domain("https://admin.shopify.com/store/cool-bikes")).to eq "cool-bikes.myshopify.com"
      expect(described_class.normalize_shop_domain("admin.shopify.com/store/cool-bikes/orders")).to eq "cool-bikes.myshopify.com"
      expect(described_class.normalize_shop_domain("https://admin.shopify.com/store/")).to be_nil
    end

    it "rejects what can't be a store" do
      expect(described_class.valid_shop_domain?("cool-bikes")).to be_truthy
      expect(described_class.valid_shop_domain?("-nope.myshopify.com")).to be_falsey
      expect(described_class.valid_shop_domain?(nil)).to be_falsey
    end
  end

  describe "creation" do
    let(:shopify_integration) { FactoryBot.create(:shopify_integration, shop_domain: "Cool-Bikes") }

    it "normalizes the domain and starts pending" do
      expect(shopify_integration).to have_attributes(shop_domain: "cool-bikes.myshopify.com",
        status: "pending", webhooks_registered_at: nil)
      expect(shopify_integration.admin_url).to eq "https://admin.shopify.com/store/cool-bikes"
      expect(shopify_integration.shop_name).to eq "cool-bikes.myshopify.com"
    end

    context "a second integration for the same shop" do
      let!(:existing) { FactoryBot.create(:shopify_integration, shop_domain: "cool-bikes.myshopify.com") }

      it "is invalid" do
        duplicate = FactoryBot.build(:shopify_integration, shop_domain: "cool-bikes")
        expect(duplicate).to_not be_valid
        expect(duplicate.errors.full_messages.to_sentence).to match(/shop domain/i)
      end

      # Uninstalling and reconnecting is ordinary, and the soft deleted row can't block it
      it "is valid once the first is destroyed" do
        existing.destroy
        expect(FactoryBot.build(:shopify_integration, shop_domain: "cool-bikes")).to be_valid
      end
    end
  end

  describe "destroy" do
    let(:shopify_integration) { FactoryBot.create(:shopify_integration, :active) }

    # Shopify revokes the token on uninstall, so keeping it only risks using a dead one
    it "soft deletes and drops the credentials" do
      shopify_integration.destroy
      expect(described_class.where(id: shopify_integration.id).count).to eq 0
      expect(shopify_integration.reload).to have_attributes(access_token: "", webhooks_registered_at: nil)
      expect(shopify_integration.deleted_at).to be_present
    end
  end

  describe "registrations_count" do
    let(:organization) { FactoryBot.create(:organization, :with_auto_user) }
    let(:shopify_integration) { FactoryBot.create(:shopify_integration, organization:) }
    let!(:bike) { FactoryBot.create(:bike_organized, :with_ownership, creation_organization: organization) }

    it "counts only the bikes the integration registered" do
      expect(shopify_integration.registrations_count).to eq 0
      bike.current_ownership.update(pos_kind: "shopify_pos")
      expect(shopify_integration.reload.registrations_count).to eq 1
    end
  end

  describe "record_error" do
    let(:shopify_integration) { FactoryBot.create(:shopify_integration, :active) }

    it "moves to error, and record_order clears it" do
      shopify_integration.record_error("webhook rejected")
      expect(shopify_integration.reload).to have_attributes(status: "error", last_error: "webhook rejected")
      expect(shopify_integration.last_error_at).to be_present

      shopify_integration.record_order
      expect(shopify_integration.reload).to have_attributes(status: "active", last_error: nil, last_error_at: nil)
      expect(shopify_integration.last_order_at).to be_present
    end
  end
end
