require "spec_helper"

describe Geohelper do
  after { Geocoder.configure(lookup: :test) }

  describe "reverse_geocode" do
    context "point" do
      let(:address) { "1740 E 2nd St, Casper, WY 82601, USA" }
      let(:latitude) { 42.8490197 }
      let(:longitude) { -106.3015341 }

      it "returns correct location" do
        Geocoder.configure(lookup: :google, use_https: true)
        VCR.use_cassette("geohelper-reverse_geocode") do
          expect(Geohelper.reverse_geocode(latitude, longitude)).to eq address
        end
      end
    end
  end
  describe "coordinates" do
    context "point" do
      let(:address) { "3550 W Shakespeare Ave, 60647" }
      let(:latitude) { 41.9202661 }
      let(:longitude) { -87.7156846 }

      it "returns correct location" do
        Geocoder.configure(lookup: :google, use_https: true)
        VCR.use_cassette("geohelper-coordinates") do
          expect(Geohelper.coordinates_for(address)).to eq({ latitude: latitude, longitude: longitude })
        end
      end
    end
  end
end
