require "rails_helper"

RSpec.describe Integrations::Shopify::Client do
  let(:secret) { described_class::SHOPIFY_SECRET }

  describe "verified_webhook?" do
    let(:body) { {"id" => 5551212, "note" => "Serial: WTU123K0912"}.to_json }
    let(:signature) { Base64.strict_encode64(OpenSSL::HMAC.digest("sha256", secret, body)) }

    it "accepts a body signed with the app secret" do
      expect(described_class.verified_webhook?(body, signature)).to be_truthy
    end

    # The signature is the only thing separating a sale from anything else POSTed at the endpoint
    it "rejects a missing, wrong, or re-used-on-other-content signature" do
      expect(described_class.verified_webhook?(body, nil)).to be_falsey
      expect(described_class.verified_webhook?(body, "")).to be_falsey
      expect(described_class.verified_webhook?(body, Base64.strict_encode64("nope"))).to be_falsey
      expect(described_class.verified_webhook?(body + " ", signature)).to be_falsey
    end

    context "no app credentials configured" do
      before { stub_const("Integrations::Shopify::Client::ENABLED", false) }

      # Otherwise a deploy missing the secret would sign everything with nil and accept it
      it "rejects even a correctly signed body" do
        expect(described_class.verified_webhook?(body, signature)).to be_falsey
      end
    end
  end

  describe "verified_callback?" do
    let(:params) do
      ActionController::Parameters.new(code: "abc123", shop: "cool-bikes.myshopify.com", state: "xyz")
    end
    let(:signed_params) { params.merge(hmac: hmac_for(params)) }

    def hmac_for(params)
      message = params.to_unsafe_h.sort.map { |k, v| "#{k}=#{v}" }.join("&")
      OpenSSL::HMAC.hexdigest("sha256", secret, message)
    end

    it "accepts Shopify's own signature over the query" do
      expect(described_class.verified_callback?(signed_params)).to be_truthy
    end

    it "rejects a signature that doesn't cover these params" do
      expect(described_class.verified_callback?(params)).to be_falsey
      expect(described_class.verified_callback?(signed_params.merge(shop: "other.myshopify.com"))).to be_falsey
    end

    # Rails adds these to every params hash and Shopify never signed them
    it "ignores controller and action" do
      expect(described_class.verified_callback?(signed_params.merge(controller: "shopify_integrations", action: "callback")))
        .to be_truthy
    end
  end

  describe "authorization_url" do
    it "points at the shop, carrying the state and our callback" do
      url = described_class.authorization_url(shop_domain: "cool-bikes.myshopify.com", state: "xyz")
      expect(url).to start_with "https://cool-bikes.myshopify.com/admin/oauth/authorize?"
      expect(url).to include "state=xyz"
      expect(url).to include CGI.escape(described_class::DEFAULT_SCOPE)
      expect(url).to include CGI.escape("/shopify_integration/callback")
    end
  end
end
