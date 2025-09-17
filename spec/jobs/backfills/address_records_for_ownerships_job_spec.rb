require "rails_helper"

RSpec.describe Backfills::AddressRecordsForOwnershipsJob, type: :job do
  let(:instance) { described_class.new }
  let(:registration_info) do
    {city: "Chicago", state: "IL", street: "1300 W 14th Pl", zipcode: "60608",
     latitude: 41.8624488, longitude: -87.6591502}
  end
  let!(:state) { FactoryBot.create(:state_illinois) }
  let(:ownership) { FactoryBot.create(:ownership) }

  before { ownership.reload.update_column :registration_info, registration_info }

  describe "build_or_create_for" do
    include_context :geocoder_real # But no VCR, because it should copy instead of geocoding

    let(:target_attrs) do
      {
        bike_id: ownership.bike_id,
        region_record_id: state.id,
        region_string: nil,
        latitude: 41.8624488,
        longitude: -87.6591502,
        city: "Chicago",
        country_id: Country.united_states_id,
        street: "1300 W 14th Pl",
        postal_code: "60608",
        kind: "ownership",
        user_id: nil
      }
    end

    it "creates for chicago" do
      expect(ownership.reload.user&.id).to be_nil
      expect(ownership.address_record_id).to be_nil
      expect(AddressRecord.count).to eq 0

      expect do
        described_class.build_or_create_for(ownership)
      end.to change(AddressRecord, :count).by 1
      expect(Callbacks::AddressRecordUpdateAssociationsJob.jobs.count).to eq 0

      expect(ownership.reload.address_record_id).to be_present
      expect(ownership.address_record).to match_hash_indifferently target_attrs

      expect { described_class.build_or_create_for(ownership) }.to_not change(AddressRecord, :count)
    end
  end

  describe "perform" do
    it "creates address_record for ownerships" do
      expect(described_class.iterable_scope.pluck(:id)).to match_array([ownership.id])

      expect do
        instance.perform
        instance.perform
      end.to change(AddressRecord, :count).by 1

      expect(ownership.reload.address_record_id).to be_present
    end
  end
end
