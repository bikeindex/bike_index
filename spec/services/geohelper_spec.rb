require "rails_helper"

RSpec.describe Geohelper do
  include_context :geocoder_real

  describe "reverse_geocode" do
    context "point" do
      let(:country) { Country.united_states}
      let!(:state) { FactoryBot.create(:state, name: 'Wyoming', abbreviation: 'WY', country: country) }
      let(:address) { "1740 E 2nd St, Casper, WY 82601, USA" }
      let(:latitude) { 42.84901970000 }
      let(:longitude) { -106.30153410000 }
      let(:returned_hash) do
        {city: "Casper", latitude: 42.8489622, longitude: -106.3014293, zipcode: "82601",
          state_id: state.id, country_id: country.id}
      end
      it "returns correct location" do
        VCR.use_cassette("geohelper-reverse_geocode") do
          expect(described_class.send(:address_hash_from_reverse_geocode, latitude, longitude)).to eq returned_hash
          # Ensure lookup_assignable_address_hash returns original lat & long
          expect(described_class.lookup_assignable_address_hash(latitude: latitude, longitude: longitude))
            .to eq(returned_hash.merge(latitude: latitude, longitude: longitude))
        end
      end
    end
  end

  describe "coordinates" do
    let(:address) { "3550 W Shakespeare Ave, 60647" }
    let(:latitude) { 41.9202661 }
    let(:longitude) { -87.7156846 }

    it "returns correct location" do
      VCR.use_cassette("geohelper-coordinates", match_requests_on: [:path]) do
        expect(described_class.coordinates_for(address)).to eq(latitude: latitude, longitude: longitude)
      end
    end

    context "blank" do
      it "handles it successfully" do
        allow(Geocoder).to receive(:search) { [] }
        expect(described_class.coordinates_for(address)).to be_nil
      end
    end

    context "zipcode" do
      let(:address) { "60647" }

      it "queries using 'zipcode: ' because google likes that" do
        expect(Geocoder).to receive(:search).with("zipcode: #{address}") { [] }
        described_class.coordinates_for(address)
      end
    end

    describe "formatted_address_hash" do
      let(:address_str) { "717 Market St, SF" }
      let(:target) do
        {
          street: "717 Market St",
          city: "San Francisco",
          state: "CA",
          zipcode: "94103",
          country: "US",
          latitude: 37.7870205,
          longitude: -122.403928
        }
      end
      it "returns our desires" do
        VCR.use_cassette("geohelper-formatted_address_hash", match_requests_on: [:path]) do
          expect(described_class.send(:formatted_address_hash, address_str)).to eq target.as_json
        end
      end
      context "blank" do
        it "returns empty" do
          expect(described_class.send(:formatted_address_hash, nil)).to eq({})
        end
      end
      context "NA" do
        it "returns empty" do
          VCR.use_cassette("geohelper-na-formatted_address_hash", match_requests_on: [:path]) do
            expect(described_class.send(:formatted_address_hash, "NA")).to eq({})
          end
        end
      end
    end

    # This is an internal method, and probably shouldn't be called from elsewhere in the code
    # but it's useful to test independently so when inevitably it fails to parse an address, we can test and resolve that case
    describe "address_hash_from_geocoder_string" do
      context "with secondary line" do
        let(:address_str) { "188 King St, UNIT 201, San Francisco, CA 94107, USA" }
        let(:target) { {street: "188 King St, UNIT 201", city: "San Francisco", state: "CA", zipcode: "94107", country: "US"} }
        it "returns our desires" do
          expect(described_class.send(:address_hash_from_geocoder_string, address_str)).to eq target.as_json
        end
      end
    end
  end

  describe "ignored_coordinates?" do
    it "returns false" do
      expect(described_class.send(:ignored_coordinates?, 42.8490197, -106.3015341)).to be_falsey
    end
    context "37.09024,-95.712891" do
      it "returns truthy" do
        expect(described_class.send(:ignored_coordinates?, 37.09024, -95.712891)).to be_truthy
        expect(described_class.send(:ignored_coordinates?, 37.090241212, -95.71289333)).to be_truthy
      end
    end
    context "71.5388001,-66.885417" do
      it "returns truthy" do
        expect(described_class.send(:ignored_coordinates?, 71.5388001, -66.885417)).to be_truthy
        expect(described_class.send(:ignored_coordinates?, 71.5388005, -66.885418)).to be_truthy # Just in case
      end
    end
  end
end
