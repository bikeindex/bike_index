require "spec_helper"

describe Geohelper do
  after { Geocoder.configure(lookup: :test) }

  describe "reverse_geocode" do
    context "point" do
      let(:address) { "1740 E 2nd St, Casper, WY 82601, USA" }
      let(:latitude) { 42.8490197 }
      let(:longitude) { -106.3015341 }

      it "returns correct location" do
        VCR.use_cassette("geohelper-reverse_geocode") do
          # Geocoder.configure(lookup: :google, use_https: true)
          expect(Geohelper.reverse_geocode(latitude, longitude)).to eq address
        end
      end
    end
  end
end
