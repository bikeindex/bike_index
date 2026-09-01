require "rails_helper"

RSpec.describe MarketplaceShipping::Quote do
  describe "for_listing" do
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale) }
    let(:base_url) { Integrations::BikeFlights::Client::BASE_URL }
    let(:rate_requests) { [] }

    before do
      Rails.cache.clear
      WebMock.stub_request(:post, "#{base_url}/api/Authentication/login")
        .to_return(status: 200, body: {token: "jwt"}.to_json,
          headers: {"Content-Type" => "application/json"})
      WebMock.stub_request(:post, "#{base_url}/api/ShopRate").to_return do |request|
        rate_requests << request
        {status: 200, body: {rates: [{total: 92.5}], requestId: "req-1"}.to_json,
         headers: {"Content-Type" => "application/json"}}
      end
    end

    after { WebMock.reset! }

    it "returns the rate, and asks for it once" do
      result = described_class.for_listing(marketplace_listing, postal_code: "80302")
      described_class.for_listing(marketplace_listing, postal_code: "80302")

      expect(result[:requestId]).to eq "req-1"
      expect(result[:rates].first[:total]).to eq 92.5
      expect(rate_requests.count).to eq 1
    end

    it "re-quotes for a different destination" do
      described_class.for_listing(marketplace_listing, postal_code: "80302")
      described_class.for_listing(marketplace_listing, postal_code: "97202")

      expect(rate_requests.count).to eq 2
    end

    it "sends the estimated package and the listing price" do
      described_class.for_listing(marketplace_listing, postal_code: "80302")

      body = JSON.parse(rate_requests.first.body)
      expect(body.dig("destination", "postalCode")).to eq "80302"
      expect(body["packages"].first).to include("length" => 45, "weight_pounds" => 45,
        "value" => marketplace_listing.amount)
    end

    context "not shippable" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, cycle_type: "cargo") }
      let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, item: bike) }

      it "returns nil without asking for a rate" do
        expect(described_class.for_listing(marketplace_listing, postal_code: "80302")).to be_nil
        expect(rate_requests.count).to eq 0
      end
    end

    context "no postal code" do
      it "returns nil without asking for a rate" do
        expect(described_class.for_listing(marketplace_listing, postal_code: nil)).to be_nil
        expect(rate_requests.count).to eq 0
      end
    end

    context "no listing" do
      it "returns nil" do
        expect(described_class.for_listing(nil, postal_code: "80302")).to be_nil
      end
    end
  end
end
