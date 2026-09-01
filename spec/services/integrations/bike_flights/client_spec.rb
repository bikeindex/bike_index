# frozen_string_literal: true

require "rails_helper"

# Stubbed rather than recorded: we have no BikeFlights account yet, so there is nothing to record a
# cassette against. Replace these with VCR cassettes once the sandbox credentials arrive - that is
# also what will confirm the field names, which currently come from their docs.
RSpec.describe Integrations::BikeFlights::Client, type: :service do
  let(:client) { described_class.new }
  let(:base_url) { described_class::BASE_URL }
  let(:token) { "jwt-token" }

  before { Rails.cache.delete(described_class::TOKEN_CACHE_KEY) }
  after { WebMock.reset! }

  def stub_login
    WebMock.stub_request(:post, "#{base_url}/api/Authentication/login")
      .to_return(status: 200, body: {token:}.to_json,
        headers: {"Content-Type" => "application/json"})
  end

  describe "token" do
    it "caches the token rather than logging in per request" do
      logins = 0
      WebMock.stub_request(:post, "#{base_url}/api/Authentication/login").to_return do
        logins += 1
        {status: 200, body: {token:}.to_json, headers: {"Content-Type" => "application/json"}}
      end
      WebMock.stub_request(:post, "#{base_url}/api/ShopRate")
        .to_return(status: 200, body: {rates: [], requestId: "req-1"}.to_json,
          headers: {"Content-Type" => "application/json"})

      client.shop_rate({shopName: "Bike Index"})
      client.shop_rate({shopName: "Bike Index"})

      expect(logins).to eq 1
    end

    context "login fails" do
      it "raises" do
        WebMock.stub_request(:post, "#{base_url}/api/Authentication/login")
          .to_return(status: 401, body: "nope")

        expect { client.countries }.to raise_error(described_class::Error, /login failed/)
      end
    end
  end

  describe "shop_rate" do
    it "returns the parsed body" do
      stub_login
      WebMock.stub_request(:post, "#{base_url}/api/ShopRate")
        .with(headers: {"Authorization" => "Bearer #{token}"})
        .to_return(status: 200, body: {rates: [{total: 92.5}], requestId: "req-1"}.to_json,
          headers: {"Content-Type" => "application/json"})

      result = client.shop_rate({shopName: "Bike Index"})

      expect(result[:requestId]).to eq "req-1"
      expect(result[:rates].first[:total]).to eq 92.5
    end

    context "the request fails" do
      it "raises with the status and body" do
        stub_login
        WebMock.stub_request(:post, "#{base_url}/api/ShopRate")
          .to_return(status: 422, body: "bad dimensions")

        expect { client.shop_rate({}) }
          .to raise_error(described_class::Error, /422.*bad dimensions/)
      end
    end
  end

  describe "create_order" do
    # the stub only matches that exact body, so a wrong one fails as an unstubbed request
    it "sends the single-use rate signature" do
      stub_login
      WebMock.stub_request(:post, "#{base_url}/api/Order/create-shop-order")
        .with(body: {requestId: "req-1", rateSignature: "sig-1", purchaseOrder: "42"})
        .to_return(status: 200, body: {orderId: "order-1"}.to_json,
          headers: {"Content-Type" => "application/json"})

      result = client.create_order(request_id: "req-1", rate_signature: "sig-1", purchase_order: "42")

      expect(result[:orderId]).to eq "order-1"
    end

    it "omits purchaseOrder when there isn't one" do
      stub_login
      WebMock.stub_request(:post, "#{base_url}/api/Order/create-shop-order")
        .with(body: {requestId: "req-1", rateSignature: "sig-1"})
        .to_return(status: 200, body: {orderId: "order-1"}.to_json,
          headers: {"Content-Type" => "application/json"})

      expect(client.create_order(request_id: "req-1", rate_signature: "sig-1")[:orderId])
        .to eq "order-1"
    end
  end

  describe "package_location" do
    it "returns the parsed body" do
      stub_login
      WebMock.stub_request(:get, "#{base_url}/api/PackageLocation/1Z999")
        .to_return(status: 200, body: {status: "delivered"}.to_json,
          headers: {"Content-Type" => "application/json"})

      expect(client.package_location("1Z999")[:status]).to eq "delivered"
    end
  end

  describe "label" do
    it "returns the pdf body rather than json" do
      stub_login
      WebMock.stub_request(:get, "#{base_url}/api/Labels/shop-label/1Z999/laser")
        .to_return(status: 200, body: "%PDF-1.4", headers: {"Content-Type" => "application/pdf"})

      expect(client.label("1Z999")).to eq "%PDF-1.4"
    end
  end
end
