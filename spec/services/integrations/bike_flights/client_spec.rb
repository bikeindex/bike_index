# frozen_string_literal: true

require "rails_helper"

# Recorded against their sandbox. To re-record, put BIKEFLIGHTS_EMAIL and BIKEFLIGHTS_PASSWORD in
# the environment - spec/rails_helper.rb filters them and the token out of the cassettes.
RSpec.describe Integrations::BikeFlights::Client, type: :service do
  let(:origin) do
    {first_name: "Test", last_name: "Seller", phone: "5035550100", address1: "2028 SE Division St",
     city: "Portland", region: "OR", postal_code: "97202", country_iso: "US"}
  end
  let(:destination) do
    {first_name: "Test", last_name: "Buyer", phone: "2125550100", address1: "278 Broadway",
     city: "New York", region: "NY", postal_code: "10007", country_iso: "US", residential: true}
  end
  let(:packages) { [{length: 45, width: 12, height: 30, weight_pounds: 45, value: 1_200}] }

  before { Rails.cache.delete(described_class::TOKEN_CACHE_KEY) }

  describe "rating, ordering, labeling and tracking a shipment" do
    it "logs in once and logs every request", vcr: {cassette_name: "bike_flights-client-order_flow"} do
      rates = described_class.shop_rate(origin:, destination:, packages:)
      expect(rates[:rates].map { it[:name] }).to eq(["UPS Next Day", "UPS 2nd Day", "UPS Ground"])

      ground = rates[:rates].last
      order = described_class.create_order(request_id: rates[:requestId],
        rate_signature: ground[:rateSignature], purchase_order: "bike-index-spec")
      expect(order[:orderId]).to be_a(Integer)

      labels = described_class.create_label(order[:orderId])
      tracking_number = labels.dig(0, "labelResponse", "boxes", 0, "trackingNumber")
      expect(tracking_number).to start_with("1Z")

      expect(described_class.label(tracking_number, label_type: "thermal")).to start_with("%PDF")

      # The sandbox's labels carry a sample tracking number, which UPS can't track
      expect { described_class.package_location(tracking_number) }
        .to raise_error(described_class::Error, /package_location failed: 404/)

      expect(BikeFlightsRequest.order(:id).pluck(:kind, :response_status)).to eq([
        ["login", 200], ["shop_rate", 200], ["create_order", 200], ["create_label", 200],
        ["label", 200], ["package_location", 404]
      ])
      expect(BikeFlightsRequest.login.first).to have_attributes(request_body: {},
        response_body: {"expiration" => a_kind_of(String)})
      expect(BikeFlightsRequest.shop_rate.first.request_body).to match({
        "shopName" => "Bike Index",
        "stage" => {
          "from" => {"firstName" => "Test", "lastName" => "Seller", "phoneNumber" => "5035550100",
                     "address1" => "2028 SE Division St", "city" => "Portland", "state" => "OR",
                     "postalCode" => "97202", "countryCode" => "US"},
          "to" => hash_including("state" => "NY", "isResidential" => true)
        },
        "packages" => [{"length" => 45, "width" => 12, "height" => 30, "value" => 1_200, "weight" => 45,
                        "linearUnit" => "IN", "weightUnit" => "LB", "contentCode" => "8000",
                        "insideDescription" => "Bicycle", "outsideDescription" => "Bicycle"}]
      })
      expect(BikeFlightsRequest.create_order.first.response_body).to eq({"orderId" => order[:orderId]})
      expect(BikeFlightsRequest.label.first.response_body).to be_nil
    end
  end

  describe "countries" do
    it "returns which countries ship", vcr: {cassette_name: "bike_flights-client-countries"} do
      countries = described_class.countries

      expect(countries.find { it["code"] == "US" }).to include("name" => "United States", "active" => true)
    end
  end

  describe "shop_rate" do
    context "a required field is missing" do
      let(:origin) { super().except(:phone) }

      it "raises with the field", vcr: {cassette_name: "bike_flights-client-shop_rate_invalid"} do
        expect { described_class.shop_rate(origin:, destination:, packages:) }
          .to raise_error(described_class::Error, /shop_rate failed: 400.*From PhoneNumber is required/)
        expect(BikeFlightsRequest.shop_rate.first.response_status).to eq 400
      end
    end
  end

  describe "login" do
    context "the password is wrong" do
      before { stub_const("#{described_class}::PASSWORD", "not-the-password") }

      it "raises", vcr: {cassette_name: "bike_flights-client-login_failed"} do
        expect { described_class.countries }.to raise_error(described_class::Error, /login failed/)
        expect(BikeFlightsRequest.pluck(:kind)).to eq(["login"])
      end
    end
  end

  context "BikeFlights is unreachable" do
    before { stub_const("#{described_class}::BASE_URL", "http://127.0.0.1:9") }

    it "raises the client's error, and logs the request" do
      expect { described_class.countries }.to raise_error(described_class::Error, /login failed/)
      expect(BikeFlightsRequest.last).to have_attributes(kind: "login", response_status: nil,
        error_message: a_string_including("refused"))
    end
  end
end
