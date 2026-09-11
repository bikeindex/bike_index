# frozen_string_literal: true

require "rails_helper"

# Stubbed rather than recorded. ShopRate's request shape below is confirmed against their sandbox
# - their API validates and names every missing field, which is how the nesting under `stage` and
# the required units were established. The responses are still invented: the account we have is a
# guest rather than a store, so ShopRate 403s and nothing has returned a real rate yet.
RSpec.describe Integrations::BikeFlights::Client, type: :service do
  let(:base_url) { described_class::BASE_URL }
  let(:token) { "jwt-token" }
  let(:expiration) { 8.hours.from_now.iso8601(3) }
  let(:origin) do
    {address1: "2028 SE Division St", city: "Portland", region: "OR",
     postal_code: "97202", country_iso: "US"}
  end
  let(:destination) do
    {address1: "278 Broadway", city: "New York", region: "NY",
     postal_code: "10007", country_iso: "US"}
  end
  let(:packages) { [{length: 45, width: 12, height: 30, weight_pounds: 45, value: 1_200}] }

  before { Rails.cache.delete(described_class::TOKEN_CACHE_KEY) }
  after { WebMock.reset! }

  def stub_login
    WebMock.stub_request(:post, "#{base_url}/api/Authentication/login")
      .to_return(status: 200, body: {token:, expiration:}.to_json,
        headers: {"Content-Type" => "application/json"})
  end

  describe "token" do
    it "caches the token rather than logging in per request" do
      logins = 0
      WebMock.stub_request(:post, "#{base_url}/api/Authentication/login").to_return do
        logins += 1
        {status: 200, body: {token:, expiration:}.to_json,
         headers: {"Content-Type" => "application/json"}}
      end
      WebMock.stub_request(:post, "#{base_url}/api/ShopRate")
        .to_return(status: 200, body: {rates: [], requestId: "req-1"}.to_json,
          headers: {"Content-Type" => "application/json"})

      2.times { described_class.shop_rate(origin:, destination:, packages:) }

      expect(logins).to eq 1
    end

    # Their expiry is read rather than guessed, so a stale one computes a negative lifetime -
    # which caches nothing and logs in on every single request
    context "the response expiration has already passed" do
      let(:expiration) { 1.hour.ago.iso8601(3) }

      it "still caches, rather than logging in per request" do
        logins = 0
        WebMock.stub_request(:post, "#{base_url}/api/Authentication/login").to_return do
          logins += 1
          {status: 200, body: {token:, expiration:}.to_json,
           headers: {"Content-Type" => "application/json"}}
        end
        WebMock.stub_request(:post, "#{base_url}/api/ShopRate")
          .to_return(status: 200, body: {requestId: "req-1"}.to_json,
            headers: {"Content-Type" => "application/json"})

        2.times { described_class.shop_rate(origin:, destination:, packages:) }

        expect(logins).to eq 1
      end
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
    # Every key here is one their sandbox rejected the request for omitting or misplacing
    it "nests both addresses under stage, and sends explicit units" do
      stub_login
      sent = nil
      WebMock.stub_request(:post, "#{base_url}/api/ShopRate")
        .with(headers: {"Authorization" => "Bearer #{token}"})
        .to_return do |request|
          sent = JSON.parse(request.body)
          {status: 200, body: {rates: [{total: 92.5}], requestId: "req-1"}.to_json,
           headers: {"Content-Type" => "application/json"}}
        end

      result = described_class.shop_rate(origin:, destination:, packages:)

      expect(sent.keys).to match_array(%w[shopName stage packages])
      expect(sent["stage"]["from"]).to eq({"address1" => "2028 SE Division St",
                                           "city" => "Portland", "stateCode" => "OR",
                                           "postalCode" => "97202", "countryCode" => "US"})
      expect(sent["stage"]["to"]["postalCode"]).to eq "10007"
      expect(sent["packages"].first).to eq({"length" => 45, "width" => 12, "height" => 30,
                                            "value" => 1_200, "weight" => 45,
                                            "linearUnit" => "IN", "weightUnit" => "LB"})
      expect(result[:requestId]).to eq "req-1"
    end

    it "defaults the country rather than sending nothing" do
      stub_login
      sent = nil
      WebMock.stub_request(:post, "#{base_url}/api/ShopRate").to_return do |request|
        sent = JSON.parse(request.body)
        {status: 200, body: {}.to_json, headers: {"Content-Type" => "application/json"}}
      end

      described_class.shop_rate(origin:, destination: destination.merge(country_iso: nil),
        packages:)

      expect(sent["stage"]["to"]["countryCode"]).to eq "US"
    end

    context "the request fails" do
      it "raises with the status and body" do
        stub_login
        WebMock.stub_request(:post, "#{base_url}/api/ShopRate")
          .to_return(status: 403, body: "International shipments are disabled")

        expect { described_class.shop_rate(origin:, destination:, packages:) }
          .to raise_error(described_class::Error, /403.*International/)
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
