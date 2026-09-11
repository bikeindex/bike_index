require "rails_helper"

RSpec.describe MarketplaceShipping::Quote do
  describe "for_listing" do
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale) }
    let(:base_url) { Integrations::BikeFlights::Client::BASE_URL }
    let(:rate_requests) { [] }
    let(:destination) do
      {address1: "278 Broadway", city: "New York", region: "NY",
       postal_code: "10007", country_iso: "US"}
    end

    before do
      Rails.cache.clear
      WebMock.stub_request(:post, "#{base_url}/api/Authentication/login")
        .to_return(status: 200, body: {token: "jwt", expiration: 8.hours.from_now.iso8601(3)}.to_json,
          headers: {"Content-Type" => "application/json"})
      WebMock.stub_request(:post, "#{base_url}/api/ShopRate").to_return do |request|
        rate_requests << request
        {status: 200, body: {rates: [{total: 92.5}], requestId: "req-1"}.to_json,
         headers: {"Content-Type" => "application/json"}}
      end
    end

    after { WebMock.reset! }

    it "returns the rate, and asks for it once" do
      result = described_class.for_listing(marketplace_listing, destination:)
      described_class.for_listing(marketplace_listing, destination:)

      expect(result[:requestId]).to eq "req-1"
      expect(result[:rates].first[:total]).to eq 92.5
      expect(rate_requests.count).to eq 1
    end

    # The bug this catches is a cache key that ignores the destination, quoting a New York
    # price to a Portland buyer
    it "re-quotes for a different destination" do
      described_class.for_listing(marketplace_listing, destination:)
      described_class.for_listing(marketplace_listing,
        destination: destination.merge(postal_code: "97202", city: "Portland", region: "OR"))

      expect(rate_requests.count).to eq 2
    end

    it "sends the seller's address as the origin, and the estimated package" do
      described_class.for_listing(marketplace_listing, destination:)

      body = JSON.parse(rate_requests.first.body)
      address_record = marketplace_listing.address_record
      expect(body.dig("stage", "from")).to include(
        "address1" => address_record.street,
        "postalCode" => address_record.postal_code,
        # region rather than region_string, which is nil for every US address
        "stateCode" => address_record.region
      )
      expect(body.dig("stage", "to", "postalCode")).to eq "10007"
      expect(body["packages"].first).to include("length" => 45, "weight" => 45,
        "linearUnit" => "IN", "value" => marketplace_listing.amount)
    end

    context "the destination has no street address" do
      it "doesn't call out - BikeFlights won't rate without one" do
        expect(described_class.for_listing(marketplace_listing,
          destination: destination.merge(address1: nil))).to be_nil
        expect(rate_requests.count).to eq 0
      end
    end

    context "a listing that can't ship" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, propulsion_type: "throttle") }
      let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale, item: bike) }

      it "doesn't call out" do
        expect(described_class.for_listing(marketplace_listing, destination:)).to be_nil
        expect(rate_requests.count).to eq 0
      end
    end

    context "BikeFlights is down" do
      before do
        WebMock.stub_request(:post, "#{base_url}/api/ShopRate")
          .to_return(status: 500, body: "nope")
      end

      # A listing page without a shipping estimate beats one that errors
      it "returns nil rather than raising, and doesn't cache the failure" do
        expect(described_class.for_listing(marketplace_listing, destination:)).to be_nil

        WebMock.stub_request(:post, "#{base_url}/api/ShopRate").to_return do |request|
          rate_requests << request
          {status: 200, body: {requestId: "req-2"}.to_json,
           headers: {"Content-Type" => "application/json"}}
        end
        expect(described_class.for_listing(marketplace_listing, destination:)[:requestId])
          .to eq "req-2"
      end
    end
  end
end
