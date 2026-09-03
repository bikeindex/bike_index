require "rails_helper"

RSpec.describe "ReverseGeocode", type: :request do
  describe "index" do
    let(:base_url) { "/reverse_geocode" }
    let(:latitude) { 42.84901970000 }
    let(:longitude) { -106.30153410000 }

    context "not logged in" do
      it "responds unauthorized" do
        get base_url, params: {latitude:, longitude:}
        expect(response.code).to eq("401")
      end
    end

    context "logged in" do
      include_context :request_spec_logged_in_as_user
      include_context :geocoder_real
      let(:vcr_config) { {match_requests_on: [:path], re_record_interval: 4.months} }
      let(:country) { Country.united_states }
      let!(:state) { FactoryBot.create(:state, name: "Wyoming", abbreviation: "WY", country:) }
      let(:target) do
        {street: "1740 East 2nd Street", city: "Casper", postal_code: "82601",
         country_id: country.id, region_record_id: state.id, region_string: nil}
      end

      def get_geocode
        VCR.use_cassette("geohelper-reverse_geocode", vcr_config) do
          get base_url, params: {latitude:, longitude:}
        end
      end

      it "returns the address fields, with the region resolved to a state" do
        get_geocode
        expect(response.code).to eq("200")
        expect(json_result).to match_hash_indifferently target
      end

      context "with coordinates it can't use" do
        it "responds bad_request" do
          [{}, {latitude: "here", longitude: "there"}, {latitude: 91, longitude:}].each do |coordinates|
            get base_url, params: coordinates
            expect(response.code).to eq("400")
          end
        end
      end

      context "with an unrecognized region" do
        let!(:state) { FactoryBot.create(:state_california) }

        it "returns region_string rather than a state" do
          get_geocode
          expect(json_result["region_record_id"]).to be_nil
          expect(json_result["region_string"]).to eq "WY"
        end
      end
    end
  end
end
