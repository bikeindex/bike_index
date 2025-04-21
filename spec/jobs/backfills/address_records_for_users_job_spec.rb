require "rails_helper"

RSpec.describe Backfills::AddressRecordsForUsersJob, type: :job do
  let(:instance) { described_class.new }
  let(:user) { FactoryBot.create(:user) }
  let(:user_amsterdam) { FactoryBot.create(:user, :in_amsterdam) }
  let(:user_chicago) { FactoryBot.create(:user, :in_chicago) }

  describe "build_or_create_for" do
    let(:target_attrs) do
      {
        user_id: user_chicago.id,
        region_record_id: user_chicago.reload.state_id,
        region_string: nil,
        latitude: 41.8624488,
        longitude: -87.6591502,
        city: "Chicago",
        country_id: Country.united_states_id,
        street: "1300 W 14th Pl",
        postal_code: "60608"
      }
    end
    it "creates for chicago" do
      expect(target_attrs[:region_record_id]).to be_present

      expect do
        described_class.build_or_create_for(user_chicago)
      end.to change(AddressRecord, :count).by 1
      expect(Callbacks::AddressRecordUpdateAssociationsJob.jobs.count).to eq 0

      expect(user_chicago.reload.address_record_id).to be_present
      expect(user_chicago.address_record).to match_hash_indifferently target_attrs

      expect(described_class.build_or_create_for(user_chicago)).to eq user_chicago.address_record
    end
  end

  describe "perform" do
    before { user && user_amsterdam && user_chicago }

    it "creates address_record for users" do
      expect(described_class.iterable_scope.pluck(:id)).to match_array([user_amsterdam.id, user_chicago.id])
      expect do
        instance.perform
        instance.perform
      end.to change(AddressRecord, :count).by 2

      expect(user_chicago.reload.address_record_id).to be_present
      expect(user_amsterdam.reload.address_record_id).to be_present
    end
  end
end
