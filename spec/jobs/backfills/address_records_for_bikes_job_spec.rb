require "rails_helper"

RSpec.describe Backfills::AddressRecordsForOwnershipsJob, type: :job do
  let(:instance) { described_class.new }
  let(:ownership) { FactoryBot.create(:ownership) }

  describe "build_or_create_for" do
    let(:target_attrs) do
      {
        bike_id: bike_chicago.id,
        region_record_id: bike_chicago.reload.state_id,
        region_string: nil,
        latitude: 41.8624488,
        longitude: -87.6591502,
        city: "Chicago",
        country_id: Country.united_states_id,
        street: "1300 W 14th Pl",
        postal_code: "60608",
        kind: "bike",
        user_id: nil
      }
    end
    it "creates for chicago" do
      expect(bike_chicago.reload.user&.id).to be_nil
      expect(target_attrs[:region_record_id]).to be_present

      expect do
        described_class.build_or_create_for(bike_chicago)
      end.to change(AddressRecord, :count).by 1
      expect(Callbacks::AddressRecordUpdateAssociationsJob.jobs.count).to eq 0

      expect(bike_chicago.reload.address_record_id).to be_present
      expect(bike_chicago.address_record).to match_hash_indifferently target_attrs

      expect(described_class.build_or_create_for(bike_chicago)).to eq bike_chicago.address_record
    end

    context "for_amsterdam" do
      let(:target_attrs) do
        {
          bike_id: bike_amsterdam.id,
          region_string: nil,
          latitude: 52.37403,
          longitude: 4.88969,
          city: "Amsterdam",
          country_id: Country.netherlands.id,
          street: "Spuistraat 134afd.Gesch.",
          postal_code: "1012",
          kind: "bike",
          user_id: bike_amsterdam.user&.id
        }
      end
      it "creates" do
        expect(bike_amsterdam.reload.user&.id).to be_present

        expect do
          described_class.build_or_create_for(bike_amsterdam)
        end.to change(AddressRecord, :count).by 1
        expect(Callbacks::AddressRecordUpdateAssociationsJob.jobs.count).to eq 0

        expect(bike_amsterdam.reload.address_record_id).to be_present
        expect(bike_amsterdam.address_record).to match_hash_indifferently target_attrs

        expect(described_class.build_or_create_for(bike_amsterdam)).to eq bike_amsterdam.address_record
      end
    end
  end

  describe "perform" do
    before { bike && bike_amsterdam && bike_chicago }

    it "creates address_record for bikes" do
      expect(described_class.iterable_scope.pluck(:id)).to match_array([bike_amsterdam.id, bike_chicago.id])
      expect do
        instance.perform
        instance.perform
      end.to change(AddressRecord, :count).by 2

      expect(bike_chicago.reload.address_record_id).to be_present
      expect(bike_amsterdam.reload.address_record_id).to be_present
    end
  end
end
