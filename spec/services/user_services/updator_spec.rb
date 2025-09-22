require "rails_helper"

RSpec.describe UserServices::Updator do
  let(:user) { FactoryBot.create(:user, email: "aftercreate@bikeindex.org") }

  describe 'assign_address_from_bikes', vcr: {cassette_name: :assign_address_from_bikes} do
    let!(:state) { FactoryBot.create(:state_california) }
    let!(:country) { Country.united_states }
    let(:target_address_hash) { {street: "Pier 15, The Embarcadero", city: "San Francisco", region: "CA", postal_code: "94111", latitude: 37.8016649, longitude: -122.397348} }
    let(:bike) do
      FactoryBot.create(:bike,
        :with_ownership_claimed,
        owner_email: "aftercreate@bikeindex.org",
        user: user,
        creation_registration_info: {phone: "(111) 222-3333"}.merge(target_address_hash))
    end
    include_context :geocoder_real

    it "assigns address record from creation" do
      expect(user).to be_present
      bike.reload.update(updated_at: Time.current)
      expect(bike.reload.registration_address_source).to eq "initial_creation"
      expect(bike.current_ownership.address_record).to be_present
      expect(bike.address_record.address_hash).to match_hash_indifferently target_address_hash
      expect(bike.address_record.kind).to eq "bike"
      expect(bike.address_record.user_id).to be_nil
      expect(bike.to_coordinates).to eq([target_address_hash[:latitude], target_address_hash[:longitude]])
      expect(user.reload.address_record_id).to be_nil

      described_class.assign_address_from_bikes(user)
      expect(user.reload.address_record_id).to be_present
      expect(user.address_record.address_hash).to eq target_address_hash
      expect(user.address_record.kind).to eq "user"
      expect(user.to_coordinates).to eq bike.to_coordinates
      expect(bike.reload.address_record.user_id).to eq user.id
      expect(bike.to_coordinates).to eq([target_address_hash[:latitude], target_address_hash[:longitude]])
      expect(bike.registration_address_source(true)).to eq "user"
      expect(AddressRecord.count).to eq 2 # sanity check ;)
    end

    context "with address record" do
      it "uses the address record"
    end

    context "with an address record assigned to a different user" do
      it "doesn't update the other user's address record"
    end

    context 'with legacy bike attrs' do
      # TODO: remove this once bike address migration finishes - #2922

    end
  end
end
