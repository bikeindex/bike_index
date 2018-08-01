require "spec_helper"

describe Geohelper do
  describe "reverse_geocode" do
    context "point" do
      let(:target) { "700 Huckleberry Hill Ln, Sylacauga, AL 35150, USA" }
      before { Geocoder.configure(lookup: :google, use_https: true) }
      after { Geocoder.configure(lookup: :test) }
      it "returns correct location" do
        VCR.use_cassette("geohelper-reverse_geocode") do
          expect(Geohelper.reverse_geocode(33.143204, -86.2246457)).to eq target
        end
      end
    end
    context "lat and lng" do
      include_context :geocoder_default_location
      it "returns correct location" do
        expect(Geohelper.reverse_geocode(default_location[:latitude], default_location[:longitude]))
          .to eq default_location[:address]
      end
    end
  end
end
