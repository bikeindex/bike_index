require "rails_helper"

RSpec.describe Geohelper do
  include_context :geocoder_real

  describe "assignable_address_hash_for" do
    let!(:country) { Country.united_states }

    context "passed coordinates" do
      let!(:state) { FactoryBot.create(:state, name: "Wyoming", abbreviation: "WY", country: country) }
      let(:address) { "1740 E 2nd St, Casper, WY 82601, USA" }
      let(:latitude) { 42.84901970000 }
      let(:longitude) { -106.30153410000 }
      let(:result_hash) do
        {city: "Casper", latitude: 42.8489622, longitude: -106.3014293, zipcode: "82601",
         state_id: state.id, country_id: country.id, neighborhood: nil, street: "1740 East 2nd Street",
         formatted_address: address}
      end
      let(:target_assignable_hash) do
        result_hash.except(:formatted_address).merge(latitude: latitude, longitude: longitude)
      end
      it "returns address_hash, with original coordinates" do
        VCR.use_cassette("geohelper-reverse_geocode") do
          expect(described_class.send(:address_hash_from_reverse_geocode, latitude, longitude)).to eq result_hash
          result = described_class.assignable_address_hash_for(latitude: latitude, longitude: longitude)
          # Ensure assignable_address_hash_for returns original lat & long
          expect(result).to eq target_assignable_hash
          expect(result.keys.map(&:to_s).sort).to eq Geocodeable.location_attrs.sort
        end
      end
    end

    context "with ignored_coordinates" do
      it "returns empty" do
        VCR.use_cassette("geohelper-us") do
          expect(described_class.assignable_address_hash_for("United States")).to eq({})
        end
      end
    end

    context "passed a bare zipcode" do
      let(:address) { "60647" }
      let!(:state) { FactoryBot.create(:state, name: "Illinois", abbreviation: "IL", country: country) }
      let(:target_assignable_hash) do
        {city: "Chicago", latitude: 41.9215421, longitude:-87.70248169999999, zipcode: "60647",
        state_id: state.id, country_id: country.id, neighborhood: nil, street: nil }
      end

      it "returns an address_hash" do
        VCR.use_cassette("geohelper-zipcode", match_requests_on: [:path]) do
          expect(described_class.assignable_address_hash_for(address)).to eq target_assignable_hash
        end
      end
    end

    context "passed an address" do
      let(:address) { "717 Market St, SF" }
      let(:target_assignable_hash) do
        {
          street: "717 Market Street",
          city: "San Francisco",
          state_id: nil,
          zipcode: "94103",
          country_id: country.id,
          neighborhood: "Yerba Buena",
          latitude: 37.7870205,
          longitude: -122.403928
        }
      end
      it "returns our desires" do
        VCR.use_cassette("geohelper-formatted_address_hash", match_requests_on: [:path]) do
          expect(described_class.assignable_address_hash_for(address)).to eq target_assignable_hash
        end
      end
    end

    context "passed an ip address" do
      let(:address) { "157.131.171.36" }
      let!(:state) { FactoryBot.create(:state_california) }
      let(:target_assignable_hash) do
        {
          street: nil,
          city: "San Francisco",
          state_id: state.id,
          zipcode: nil,
          country_id: country.id,
          neighborhood: nil,
          latitude: 37.7506,
          longitude: -122.4121
        }
      end
      it "finds the address" do
        VCR.use_cassette("geohelper-ip_address", match_requests_on: [:path]) do
          expect(described_class.assignable_address_hash_for(address)).to eq target_assignable_hash
        end
      end
    end
  end

  describe "coordinates_for" do
    let(:address) { "3550 W Shakespeare Ave, 60647" }
    let(:latitude) { 41.9202661 }
    let(:longitude) { -87.7156846 }

    it "returns correct location" do
      VCR.use_cassette("geohelper-coordinates", match_requests_on: [:path]) do
        expect(described_class.coordinates_for(address)).to eq(latitude: latitude, longitude: longitude)
      end
    end

    context "with blank" do
      it "handles it successfully" do
        expect(described_class.coordinates_for(' ')).to eq({latitude: nil, longitude: nil})
      end
    end

    context "with ignored_coordinates" do
      it "returns nil" do
        VCR.use_cassette("geohelper-coordinates-US", match_requests_on: [:path]) do
          expect(described_class.coordinates_for("United States")).to eq(latitude: nil, longitude: nil)
        end
      end
    end

    context "zipcode" do
      let(:address) { "60647" }
      let(:latitude) { 41.9215421 }
      let(:longitude) { -87.70248169999999 }

      it "queries using 'zipcode: ' because google likes that" do
        expect(Geocoder).to receive(:search).with("zipcode: #{address}") { [] }
        described_class.coordinates_for(address)
      end

      it "returns coordinates" do
        VCR.use_cassette("geohelper-zipcode", match_requests_on: [:path]) do
          expect(described_class.coordinates_for(address)).to eq(latitude: latitude, longitude: longitude)
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

  # # NOT SURE WE'RE KEEPING THIS ANYWAY!
  # # This is an internal method, and probably shouldn't be called from elsewhere in the code
  # # but it's useful to test independently so when inevitably it fails to parse an address, we can test and resolve that case
  # describe "address_hash_from_geocoder_string" do
  #   context "with secondary line" do
  #     let(:address_str) { "188 King St, UNIT 201, San Francisco, CA 94107, USA" }
  #     let(:target) { {street: "188 King St, UNIT 201", city: "San Francisco", state: "CA", zipcode: "94107", country: "US"} }
  #     it "returns our desires" do
  #       expect(described_class.send(:address_hash_from_geocoder_string, address_str)).to eq target.as_json
  #     end
  #   end
  # end

  # describe "formatted_address_hash" do
  #   let(:address_str) { "717 Market St, SF" }
  #   let(:target) do
  #     {
  #       street: "717 Market St",
  #       city: "San Francisco",
  #       state: "CA",
  #       zipcode: "94103",
  #       country: "US",
  #       latitude: 37.7870205,
  #       longitude: -122.403928
  #     }
  #   end
  #   it "returns our desires" do
  #     VCR.use_cassette("geohelper-formatted_address_hash", match_requests_on: [:path]) do
  #       expect(described_class.send(:formatted_address_hash, address_str)).to eq target.as_json
  #     end
  #   end
  #   context "blank" do
  #     it "returns empty" do
  #       expect(described_class.send(:formatted_address_hash, nil)).to eq({})
  #     end
  #   end
  #   context "NA" do
  #     it "returns empty" do
  #       VCR.use_cassette("geohelper-na-formatted_address_hash", match_requests_on: [:path]) do
  #         expect(described_class.send(:formatted_address_hash, "NA")).to eq({})
  #       end
  #     end
  #   end
  # end
end
