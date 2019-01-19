require "spec_helper"

describe Geohelper do
  include_context :geocoder_real

  describe "reverse_geocode" do
    context "point" do
      let(:address) { "1740 E 2nd St, Casper, WY 82601, USA" }
      let(:latitude) { 42.8490197 }
      let(:longitude) { -106.3015341 }

      it "returns correct location" do
        VCR.use_cassette("geohelper-reverse_geocode") do
          expect(Geohelper.reverse_geocode(latitude, longitude)).to eq address
        end
      end
    end
  end

  describe "coordinates" do
    let(:address) { "3550 W Shakespeare Ave, 60647" }
    let(:latitude) { 41.9202661 }
    let(:longitude) { -87.7156846 }

    it "returns correct location" do
      VCR.use_cassette("geohelper-coordinates") do
        expect(Geohelper.coordinates_for(address)).to eq(latitude: latitude, longitude: longitude)
      end
    end

    context "blank" do
      it "handles it successfully" do
        allow(Geocoder).to receive(:search) { [] }
        expect(Geohelper.coordinates_for(address)).to be_nil
      end
    end

    context "zipcode" do
      let(:address) { "60647" }

      it "queries using 'zipcode: ' because google likes that" do
        expect(Geocoder).to receive(:search).with("zipcode: #{address}") { [] }
        Geohelper.coordinates_for(address)
      end
    end

    describe "formatted_address_hash" do
      let(:address_str) { "717 Market St, SF" }
      let(:target) do
        {
          address: "717 Market St",
          city: "San Francisco",
          state: "CA",
          zipcode: "94103",
          country: "USA",
          latitude: 37.7870322,
          longitude: -122.4039235
        }
      end
      it "returns our desires" do
        VCR.use_cassette("geohelper-formatted_address_hash") do
          expect(Geohelper.formatted_address_hash(address_str)).to eq target.as_json
        end
      end
    end

    # This is an internal method, and probably shouldn't be called from elsewhere in the code
    # but it's useful to test independently so when inevitably it fails to parse an address, we can test and resolve that case
    describe "address_hash_from_geocoder_result" do
      context "with secondary line" do
        let(:address_str) { "188 King St, UNIT 201, San Francisco, CA 94107, USA" }
        let(:target) { { address: "188 King St, UNIT 201", city: "San Francisco", state: "CA", zipcode: "94107", country: "USA" } }
        it "returns our desires" do
          expect(Geohelper.address_hash_from_geocoder_result(address_str)).to eq target.as_json
        end
      end
    end
  end
end
