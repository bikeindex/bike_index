require "rails_helper"

RSpec.describe Backfills::AddressRecordForceGeocodeJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let(:country_id) { Country.united_states.id }
    let(:region_record_id) { FactoryBot.create(:state_california).id }
    let(:latitude) { 37.761423 }
    let(:longitude) { -122.424095 }
    let!(:address_record) do
      AddressRecord.create(postal_code: "94110", region_record_id:, country_id:, skip_geocoding: true,
        latitude:, longitude:)
    end
    let(:target_attrs) do
      {
        region_record_id:,
        region_string: nil,
        postal_code: "94110",
        street: nil,
        city: "San Francisco",
        latitude: 37.7485824, # reassigns to postal code location
        longitude: -122.4184108 # reassigns to postal code location
      }
    end

    include_context :geocoder_real

    it "force geocodes address_record" do
      expect(address_record.reload.city).to be_blank

      VCR.use_cassette("backfill-address-record-force-geocode") do
        instance.perform(address_record.id)

        expect(address_record.reload).to match_hash_indifferently target_attrs
      end
    end
  end
end
