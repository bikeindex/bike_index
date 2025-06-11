require "rails_helper"

RSpec.describe Backfills::AddressRecordForceGeocodeJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let(:country_id) { Country.united_states.id }
    let(:region_record_id) { FactoryBot.create(:state_california).id }
    let!(:address_record) { AddressRecord.create(postal_code: "95616", region_record_id:, country_id:, skip_geocoding: true) }
    let(:target_attrs) do
      {
        region_record_id:,
        region_string: nil,
        postal_code: "95616",
        street: nil,
        city: "Davis",
        latitude: 38.5474428,
        longitude: -121.7765309
      }
    end

    include_context :geocoder_real

    it "force geocodes address_record" do
      expect(address_record.reload.city).to be_blank

      VCR.use_cassette("address-record-assignment_geocode") do
        instance.perform(address_record.id)

        expect(address_record.reload).to match_hash_indifferently target_attrs
      end
    end
  end
end
