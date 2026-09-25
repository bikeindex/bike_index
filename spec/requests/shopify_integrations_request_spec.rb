require "rails_helper"

RSpec.describe ShopifyIntegrationsController, type: :request do
  include_context :request_spec_logged_in_as_user

  let(:base_url) { "/shopify_integration" }
  let(:organization) { FactoryBot.create(:organization, :with_auto_user, kind: "bike_shop") }
  let(:current_user) { FactoryBot.create(:organization_admin, organization:) }

  describe "new" do
    it "renders the connect form" do
      get "#{base_url}/new", params: {organization_id: organization.to_param}
      expect(response).to render_template(:new)
      expect(response.body).to match("Connect Shopify")
    end

    context "already connected" do
      let!(:shopify_integration) do
        FactoryBot.create(:shopify_integration, :active, organization:,
          shop_domain: "cool-bikes.myshopify.com", last_order_at: Time.current - 1.hour)
      end

      it "renders the shop it's connected to" do
        get "#{base_url}/new", params: {organization_id: organization.to_param}
        expect(response).to render_template(:new)
        expect(response.body).to match("cool-bikes.myshopify.com")
        expect(response.body).to match("Disconnect")
      end
    end

    context "not an admin of the organization" do
      let(:current_user) { FactoryBot.create(:organization_user, organization:) }

      it "redirects" do
        get "#{base_url}/new", params: {organization_id: organization.to_param}
        expect(response).to redirect_to(my_account_path)
        expect(flash[:error]).to be_present
      end
    end
  end

  describe "create" do
    it "sends the merchant to Shopify to authorize" do
      post base_url, params: {organization_id: organization.to_param, shop_domain: "cool-bikes"}
      expect(response).to redirect_to(/cool-bikes\.myshopify\.com\/admin\/oauth\/authorize/)
      expect(session[:shopify_oauth]).to include("organization_id" => organization.id,
        "shop_domain" => "cool-bikes.myshopify.com")
    end

    context "an address that can't be a store" do
      it "returns to the form" do
        post base_url, params: {organization_id: organization.to_param, shop_domain: "-nope.myshopify.com"}
        expect(response).to redirect_to(new_shopify_integration_path(organization_id: organization.to_param))
        expect(flash[:error]).to be_present
        expect(session[:shopify_oauth]).to be_blank
      end
    end
  end

  describe "callback" do
    let(:shop_domain) { "cool-bikes.myshopify.com" }

    # The OAuth state only exists in a session the merchant's own browser holds, and a
    # callback arriving without it is someone else's redirect
    it "refuses a callback with no authorization in flight" do
      expect {
        get "#{base_url}/callback", params: {code: "abc123", shop: shop_domain, state: "made-up", hmac: "nope"}
      }.to_not change(ShopifyIntegration, :count)
      expect(response).to redirect_to(my_account_path)
      expect(flash[:error]).to match(/state/i)
    end
  end

  describe "destroy" do
    let!(:shopify_integration) { FactoryBot.create(:shopify_integration, :active, organization:) }

    it "disconnects" do
      delete base_url, params: {organization_id: organization.to_param}
      expect(response).to redirect_to(organization_manage_path(organization_id: organization.to_param))
      expect(ShopifyIntegration.where(id: shopify_integration.id).count).to eq 0
    end

    context "an admin of a different organization" do
      let(:current_user) { FactoryBot.create(:organization_admin) }

      it "does not" do
        delete base_url, params: {organization_id: organization.to_param}
        expect(response).to redirect_to(my_account_path)
        expect(ShopifyIntegration.where(id: shopify_integration.id).count).to eq 1
      end
    end
  end
end
