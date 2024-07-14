require "rails_helper"

RSpec.describe GeocodeHelper do
  include_context :geocoder_real
  let(:vcr_config) { {match_requests_on: [:path], re_record_interval: 3.months} }

  describe "assignable_address_hash_for" do
    let!(:country) { Country.united_states }

    context "passed coordinates" do
      let!(:state) { FactoryBot.create(:state, name: "Wyoming", abbreviation: "WY", country: country) }
      let(:address) { "1740 E 2nd St, Casper, WY 82601, USA" }
      let(:latitude) { 42.84901970000 }
      let(:longitude) { -106.30153410000 }
      let(:result_hash) do
        {city: "Casper", latitude: 42.8489653, longitude: -106.3014667, zipcode: "82601",
         state_id: state.id, country_id: country.id, neighborhood: nil, street: "1740 East 2nd Street",
         formatted_address: address}
      end
      let(:target_assignable_hash) do
        result_hash.except(:formatted_address).merge(latitude: latitude, longitude: longitude)
      end
      it "returns address_hash, with original coordinates" do
        VCR.use_cassette("geohelper-reverse_geocode", vcr_config) do
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
        VCR.use_cassette("geohelper-us", vcr_config) do
          expect(described_class.assignable_address_hash_for("United States")).to eq({})
        end
      end
    end

    context "passed a bare zipcode" do
      let(:address) { "60647" }
      let!(:state) { FactoryBot.create(:state, name: "Illinois", abbreviation: "IL", country: country) }
      let(:target_assignable_hash) do
        {city: "Chicago", latitude: 41.9215421, longitude: -87.70248169999999, zipcode: "60647",
         state_id: state.id, country_id: country.id, neighborhood: nil, street: nil}
      end

      it "returns an address_hash" do
        VCR.use_cassette("geohelper-zipcode", vcr_config) do
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
          latitude: 37.78698199999999,
          longitude: -122.403855
        }
      end
      it "returns our desires" do
        VCR.use_cassette("geohelper-formatted_address_hash", vcr_config) do
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
        VCR.use_cassette("geohelper-ip_address", vcr_config) do
          expect(described_class.assignable_address_hash_for(address)).to eq target_assignable_hash
        end
      end
    end
  end

  describe "coordinates_for" do
    let(:address) { "3550 W Shakespeare Ave, 60647" }
    let(:latitude) { 41.9202668 }
    let(:longitude) { -87.71563359999999 }

    it "returns correct location" do
      VCR.use_cassette("geohelper-coordinates", vcr_config) do
        expect(described_class.coordinates_for(address)).to eq(latitude: latitude, longitude: longitude)
      end
    end

    context "with blank" do
      it "handles it successfully" do
        expect(described_class.coordinates_for(" ")).to eq({latitude: nil, longitude: nil})
      end
    end

    context "with ignored_coordinates" do
      it "returns nil" do
        VCR.use_cassette("geohelper-coordinates-US", vcr_config) do
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
        VCR.use_cassette("geohelper-zipcode", vcr_config) do
          expect(described_class.coordinates_for(address)).to eq(latitude: latitude, longitude: longitude)
        end
      end
    end
  end

  describe "bounding_box" do
    context "san francisco" do
      let(:target) do
        [37.63019771688915, -122.60252221724598, 37.91966128311085, -122.23630878275402]
      end
      it "returns the box" do
        VCR.use_cassette("geohelper-boundingbox", vcr_config) do
          expect(described_class.bounding_box("San Francisco, CA", 10)).to eq target
        end
      end
    end
    context "passed coordinate array" do
      let(:target) do
        [42.70428791688915, -106.498945433829, 42.99375148311085, -106.104122766171]
      end
      it "returns the box" do
        expect(described_class.bounding_box([42.8490197, -106.3015341], 10)).to eq target
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
