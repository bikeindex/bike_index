require 'rails_helper'

RSpec.describe AddressRecord, type: :model do
  describe "factory" do
    let(:address_record) { FactoryBot.create(:address_record) }
    it "is valid" do
      expect(address_record).to be_valid
      expect(address_record.region).to eq "CA"
      expect(address_record.formatted_address_string).to eq "Davis, CA, 95616"
      expect(address_record.formatted_address_string(render_country: 'always')).to eq "Davis, CA, 95616, United States"

      expect(address_record.formatted_address_string(render_country: :if_different)).to eq "Davis, CA, 95616"
      expect(address_record.formatted_address_string(render_country: :if_different, current_country_iso: "CA"))
        .to eq "Davis, CA, 95616, United States"
      # include_country defaults to :if_different if not matching
      expect(address_record.formatted_address_string(render_country: 'something')).to eq "Davis, CA, 95616"
    end
    context "in_amsterdam" do
      let(:address_record) { FactoryBot.create(:address_record, :amsterdam) }
      it "is valid" do
        expect(address_record).to be_valid
        expect(address_record.region).to eq "North Holland"
        expect(address_record.formatted_address_string(render_country: :always)).to eq "Amsterdam, North Holland, 1012, Netherlands"
        expect(address_record.formatted_address_string).to eq "Amsterdam, North Holland, 1012, Netherlands"
        expect(address_record.formatted_address_string(current_country_iso: "NL")).to eq "Amsterdam, North Holland, 1012"
      end
    end
  end

  describe "assignment" do
    let(:address_record) do
      AddressRecord.create(street: "   ", city: "\n", postal_code:, region_string:, country_id:, skip_geocoding:)
    end
    let(:region_string) { "California " }
    let(:country_id) { Country.united_states.id }
    let(:postal_code) { " 95616" }
    let!(:region_record_id) { FactoryBot.create(:state_california).id }
    let(:skip_geocoding) { true }
    let(:target_attrs) do
      {
        region_record_id:,
        postal_code: "95616",
        street: nil,
        city: nil,
        region_string: nil,
        latitude: nil,
        longitude: nil
      }
    end
    include_context :geocoder_real

    it "strips and removes blanks" do
      expect(address_record).to be_valid

      expect(address_record.reload).to match_hash_indifferently target_attrs
    end

    context "with geocode" do
      let(:skip_geocoding) { false }
      let(:target_attrs) do
        {
          region_record_id:,
          postal_code: "95616",
          street: nil,
          city: "Davis",
          region_string: nil,
          latitude: 38.5474428,
          longitude: -121.7765309
        }
      end

      it "geocodes" do
        VCR.use_cassette("address-record-assignment_geocode") do
          expect(address_record).to be_valid

          expect(address_record.reload).to match_hash_indifferently target_attrs
        end
      end

      context "with an update" do
        xit "overwrites the latitude and longitude" do

        end
      end
    end
  end
end
