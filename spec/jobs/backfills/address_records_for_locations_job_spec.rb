require "rails_helper"

RSpec.describe Backfills::AddressRecordsForLocationsJob, type: :job do
  let(:instance) { described_class.new }
  let(:location) { FactoryBot.create(:location_chicago, skip_update: true) }

  describe "build_or_create_for" do
    let(:target_attrs) do
      {
        organization_id: location.organization_id,
        region_record_id: location.state_id,
        region_string: nil,
        latitude: location.latitude,
        longitude: location.longitude,
        city: location.city,
        country_id: location.country_id,
        street: location.street,
        postal_code: location.zipcode,
        kind: "organization",
        user_id: nil
      }
    end

    it "creates for chicago" do
      expect(location.reload.address_record_id).to be_nil
      expect(AddressRecord.count).to eq 0

      expect do
        described_class.build_or_create_for(location)
      end.to change(AddressRecord, :count).by 1
      expect(CallbackJob::AddressRecordUpdateAssociationsJob.jobs.count).to eq 0

      expect(location.reload.address_record_id).to be_present
      expect(location.address_record).to match_hash_indifferently target_attrs

      expect { described_class.build_or_create_for(location) }.to_not change(AddressRecord, :count)
    end
  end

  describe "perform" do
    let(:location2) { FactoryBot.create(:location_nyc, skip_update: true) }

    before { location && location2 }

    it "creates address_record for locations with address data" do
      expect(described_class.iterable_scope.pluck(:id)).to match_array([location.id, location2.id])

      expect do
        instance.perform
        instance.perform
      end.to change(AddressRecord, :count).by 2

      expect(location.reload.address_record_id).to be_present
      expect(location2.reload.address_record_id).to be_present
    end
  end
end
