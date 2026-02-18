require "rails_helper"

RSpec.describe UserServices::Updator do
  let(:user) { FactoryBot.create(:user, :confirmed, email: "aftercreate@bikeindex.org") }

  describe "assign_address_from_bikes", vcr: {cassette_name: :assign_address_from_bikes} do
    let!(:state) { FactoryBot.create(:state_california) }
    let!(:country) { Country.united_states }
    let(:reg_info_hash) { {street: "Pier 15, The Embarcadero", city: "San Francisco", state: "CA", zipcode: "94111", latitude: 37.8016649, longitude: -122.397348} }
    let(:target_address_hash) { reg_info_hash.except(:state, :zipcode).merge(region: "CA", postal_code: "94111", street_2: nil) }
    let(:bike) do
      FactoryBot.create(:bike,
        :with_ownership,
        owner_email: "aftercreate@bikeindex.org",
        creation_registration_info: {phone: "(111) 222-3333"}.merge(reg_info_hash))
    end
    include_context :geocoder_real

    it "assigns address record from creation" do
      expect(bike.reload.current_ownership.user_id).to be_blank
      expect(user).to be_present
      bike.current_ownership.mark_claimed
      expect(bike.current_ownership.reload.user_id).to eq user.id
      bike.update(updated_at: Time.current)
      expect(BikeServices::CalculateLocation.registration_address_source(bike.reload)).to eq "initial_creation"
      expect(bike.current_ownership.address_record).to be_present
      expect(bike.current_ownership.address_record.country_id).to eq Country.united_states_id
      expect(bike.address_record.address_hash(visible_attribute: :street).except(:country))
        .to match_hash_indifferently target_address_hash
      expect(bike.address_record.kind).to eq "ownership"
      expect(bike.address_record.user_id).to be_blank
      expect(bike.to_coordinates).to eq([target_address_hash[:latitude], target_address_hash[:longitude]])
      expect(user.reload.address_record_id).to be_nil

      described_class.assign_address_from_bikes(user, save_user: true)

      expect(user.reload.address_record_id).to be_present
      expect(user.address_record.address_hash(visible_attribute: :street)).to eq target_address_hash
      expect(user.address_record.kind).to eq "user"
      expect(user.to_coordinates).to eq bike.to_coordinates
      expect(user.address_set_manually).to be_falsey

      expect(bike.reload.address_record.user_id).to eq user.id
      expect(bike.to_coordinates).to eq([target_address_hash[:latitude], target_address_hash[:longitude]])
      expect(BikeServices::CalculateLocation.registration_address_source(bike)).to eq "initial_creation"
      expect(AddressRecord.count).to eq 2 # sanity check ;)
    end

    context "with address record" do
      let(:bike) do
        FactoryBot.create(:bike, :with_ownership, :with_address_record, address_in: :los_angeles,
          owner_email: "aftercreate@bikeindex.org", address_set_manually: true)
      end
      let(:target_coordinates) { [34.05223, -118.24368] }
      let(:address_record) { bike.address_record }

      it "uses the address record" do
        expect(bike.reload.current_ownership.user_id).to be_blank
        expect(user).to be_present
        bike.current_ownership.mark_claimed
        expect(bike.current_ownership.reload.user_id).to eq user.id
        bike.update(updated_at: Time.current)
        expect(BikeServices::CalculateLocation.registration_address_source(bike.reload)).to eq "bike_update"
        expect(bike.to_coordinates).to eq target_coordinates
        expect(address_record.to_coordinates).to eq target_coordinates
        expect(address_record.user_id).to be_blank
        expect(user.reload.address_record_id).to be_nil

        described_class.assign_address_from_bikes(user, save_user: true)

        expect(user.reload.address_record_id).to be_present
        expect(user.address_record.to_coordinates).to eq target_coordinates
        expect(user.address_record.kind).to eq "user"
        expect(user.address_set_manually).to be_truthy

        expect(bike.reload.address_record.user_id).to eq user.id
        expect(bike.to_coordinates).to eq target_coordinates
        expect(BikeServices::CalculateLocation.registration_address_source(bike)).to eq "user"
        expect(AddressRecord.count).to eq 2 # sanity check ;)
      end

      context "with an address record assigned to a different user" do
        let(:other_user) { FactoryBot.create(:user, :confirmed) }

        # IDK, maybe this shouldn't take the address? Just making something work for now
        it "doesn't update the other user's address record, but does take the address" do
          expect(bike.reload.current_ownership.user_id).to be_blank
          address_record.update(user_id: other_user.id)
          expect(user).to be_present
          bike.current_ownership.mark_claimed
          expect(bike.current_ownership.reload.user_id).to eq user.id
          bike.update(updated_at: Time.current)
          expect(BikeServices::CalculateLocation.registration_address_source(bike.reload)).to eq "bike_update"
          expect(bike.to_coordinates).to eq target_coordinates
          expect(address_record.to_coordinates).to eq target_coordinates
          expect(user.reload.address_record_id).to be_nil

          described_class.assign_address_from_bikes(user, save_user: true)

          expect(user.reload.address_record_id).to be_present
          expect(user.address_record.to_coordinates).to eq target_coordinates
          expect(user.address_record.kind).to eq "user"
          expect(user.address_set_manually).to be_truthy

          expect(bike.reload.address_record.user_id).to eq other_user.id
          expect(bike.to_coordinates).to eq target_coordinates
          expect(BikeServices::CalculateLocation.registration_address_source(bike)).to eq "user"
          expect(AddressRecord.count).to eq 2 # sanity check ;)
        end
      end
    end

    context "with legacy bike attrs" do
      # TODO: remove this once bike address migration finishes - #2922
      let(:bike) do
        FactoryBot.create(:bike, :with_ownership, :in_los_angeles, owner_email: "aftercreate@bikeindex.org", address_set_manually: true)
      end
      let(:legacy_hash) { {street: "100 W 1st St", city: "Los Angeles", state: "CA", zipcode: "90021", latitude: 34.05223, longitude: -118.24368, country: "US"} }
      let(:target_address_hash) { legacy_hash.except(:state, :zipcode, :country).merge(region: "CA", postal_code: "90021", street_2: nil) }

      it "updates from the bike attrs" do
        expect(bike.reload.current_ownership.user_id).to be_blank
        expect(user).to be_present
        bike.current_ownership.mark_claimed
        expect(bike.current_ownership.reload.user_id).to eq user.id
        bike.update(updated_at: Time.current)
        expect(BikeServices::CalculateLocation.registration_address_source(bike.reload)).to eq "bike_update"
        expect(bike.address_hash_legacy).to match_hash_indifferently legacy_hash

        described_class.assign_address_from_bikes(user, save_user: true)

        expect(user.reload.address_record_id).to be_present
        expect(user.address_record.address_hash(visible_attribute: :street)).to eq target_address_hash
        expect(user.address_record.kind).to eq "user"
        expect(user.to_coordinates).to eq bike.to_coordinates
        expect(user.address_set_manually).to be_truthy

        expect(bike.reload.address_record.user_id).to eq user.id
        expect(bike.to_coordinates).to eq([target_address_hash[:latitude], target_address_hash[:longitude]])
        expect(BikeServices::CalculateLocation.registration_address_source(bike)).to eq "user"
        expect(AddressRecord.count).to eq 1
      end
    end
  end
end
