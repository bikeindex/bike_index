require "rails_helper"

RSpec.describe Backfills::AddressRecordsForImpoundRecordsJob, type: :job do
  let(:instance) { described_class.new }
  let!(:state) { FactoryBot.create(:state_illinois) }
  let(:impound_record) { FactoryBot.create(:impound_record) }

  let(:location_attrs) do
    {
      city: "Chicago",
      state_id: state.id,
      street: "1300 W 14th Pl",
      zipcode: "60608",
      country_id: Country.united_states_id,
      latitude: 41.8624488,
      longitude: -87.6591502
    }
  end

  before { impound_record.update_columns(location_attrs) }

  describe "build_or_create_for" do
    let(:target_attrs) do
      {
        region_record_id: state.id,
        region_string: nil,
        latitude: 41.8624488,
        longitude: -87.6591502,
        city: "Chicago",
        country_id: Country.united_states_id,
        street: "1300 W 14th Pl",
        postal_code: "60608",
        kind: "impound_record",
        user_id: impound_record.user_id
      }
    end

    it "creates for chicago" do
      expect(impound_record.reload.address_record_id).to be_nil
      expect(AddressRecord.count).to eq 0

      expect do
        described_class.build_or_create_for(impound_record)
      end.to change(AddressRecord, :count).by 1
      expect(CallbackJob::AddressRecordUpdateAssociationsJob.jobs.count).to eq 0

      expect(impound_record.reload.address_record_id).to be_present
      expect(impound_record.address_record).to match_hash_indifferently target_attrs

      expect { described_class.build_or_create_for(impound_record) }.to_not change(AddressRecord, :count)
    end
  end

  describe "perform" do
    let(:impound_record_no_location) { FactoryBot.create(:impound_record) }

    before { impound_record_no_location }

    it "creates address_record for impound_records with location" do
      expect(described_class.iterable_scope.pluck(:id)).to match_array([impound_record.id])

      expect do
        instance.perform
        instance.perform
      end.to change(AddressRecord, :count).by 1

      expect(impound_record.reload.address_record_id).to be_present
      expect(impound_record_no_location.reload.address_record_id).to be_nil
    end
  end
end
