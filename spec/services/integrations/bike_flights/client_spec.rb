# frozen_string_literal: true

require "rails_helper"

# Stubbed rather than recorded: we have no BikeFlights account yet, so there is nothing to record a
# cassette against. Replace these with VCR cassettes once the sandbox credentials arrive - that is
# also what will confirm the field names, which currently come from their docs.
RSpec.describe Integrations::BikeFlights::Client, type: :service do
  let(:base_url) { described_class::BASE_URL }
  let(:token) { "jwt-token" }
  let(:origin) { {postal_code: "97202", city: "Portland", region: "OR", country_iso: "US"} }
  let(:destination) { {postal_code: "10007", country_iso: "US"} }
  let(:packages) { [{length: 45, width: 12, height: 30, weight_pounds: 45}] }

  before { Rails.cache.delete(described_class::TOKEN_CACHE_KEY) }
  after { WebMock.reset! }

  def stub_login
    WebMock.stub_request(:post, "#{base_url}/api/Authentication/login")
      .to_return(status: 200, body: {token:}.to_json,
        headers: {"Content-Type" => "application/json"})
  end

  def stub_shop_rate(body = {rates: [], requestId: "req-1"})
    WebMock.stub_request(:post, "#{base_url}/api/ShopRate")
      .to_return(status: 200, body: body.to_json,
        headers: {"Content-Type" => "application/json"})
  end

  describe "token" do
    it "caches the token rather than logging in per request" do
      logins = 0
      WebMock.stub_request(:post, "#{base_url}/api/Authentication/login").to_return do
        logins += 1
        {status: 200, body: {token:}.to_json, headers: {"Content-Type" => "application/json"}}
      end
      stub_shop_rate

      2.times { described_class.shop_rate(origin:, destination:, packages:) }

      expect(logins).to eq 1
    end

    context "login fails" do
      it "raises" do
        WebMock.stub_request(:post, "#{base_url}/api/Authentication/login")
          .to_return(status: 401, body: "nope")

        expect { described_class.countries }.to raise_error(described_class::Error, /login failed/)
      end
    end
  end

  describe "shop_rate" do
    it "maps the address to their field names, and defaults the country" do
      stub_login
      sent = nil
      WebMock.stub_request(:post, "#{base_url}/api/ShopRate")
        .with(headers: {"Authorization" => "Bearer #{token}"})
        .to_return do |request|
          sent = JSON.parse(request.body)
          {status: 200, body: {rates: [{total: 92.5}], requestId: "req-1"}.to_json,
           headers: {"Content-Type" => "application/json"}}
        end

      result = described_class.shop_rate(origin:, destination: {postal_code: "10007"}, packages:)

      expect(sent["origin"]).to eq({"postalCode" => "97202", "city" => "Portland",
                                    "state" => "OR", "country" => "US"})
      expect(sent["destination"]).to eq({"postalCode" => "10007", "country" => "US"})
      expect(result[:requestId]).to eq "req-1"
      expect(result[:rates].first[:total]).to eq 92.5
    end

    context "the request fails" do
      it "raises with the status and body" do
        stub_login
        WebMock.stub_request(:post, "#{base_url}/api/ShopRate")
          .to_return(status: 422, body: "bad dimensions")

        expect { described_class.shop_rate(origin:, destination:, packages:) }
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

      result = described_class.create_order(request_id: "req-1", rate_signature: "sig-1",
        purchase_order: "42")

      expect(result[:orderId]).to eq "order-1"
    end
  end

  describe "label" do
    it "returns the pdf body rather than json" do
      stub_login
      WebMock.stub_request(:get, "#{base_url}/api/Labels/shop-label/1Z999/laser")
        .to_return(status: 200, body: "%PDF-1.4", headers: {"Content-Type" => "application/pdf"})

      expect(described_class.label("1Z999")).to eq "%PDF-1.4"
    end
  end
end
