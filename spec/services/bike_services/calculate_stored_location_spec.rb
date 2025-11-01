require "rails_helper"

RSpec.describe BikeServices::CalculateStoredLocation do
  describe "location_attrs" do
    let!(:usa) { Country.united_states }

    context "given a current_stolen_record and no bike location info" do
      let(:bike) { FactoryBot.create(:stolen_bike_in_chicago) }
      let(:stolen_record) { bike.current_stolen_record }
      let(:street_address) { "1300 W 14th Pl" }
      let(:abbr_address) { "Chicago, IL 60608, US" }
      let(:full_address) { "#{street_address}, #{abbr_address}" }
      it "takes location from the current stolen record" do
        expect(stolen_record.street).to eq street_address
        expect(stolen_record.address(force_show_address: true)).to eq(full_address)
        expect(stolen_record.address).to eq(abbr_address)

        bike.reload
        stolen_record.save
        bike.save
        expect(StolenRecord.unscoped.where(bike_id: bike.id).count).to eq 1

        expect(bike.to_coordinates).to eq(stolen_record.to_coordinates)
        expect(bike.address_record_id).to be_blank
      end
      context "removing location from the stolen_record" do
        include_context :geocoder_real
        # When displaying searches for stolen bikes, it's critical we honor the stolen record's data
        # ... or else unexpected things happen
        it "blanks the location on the bike" do
          expect(stolen_record.address(force_show_address: true)).to eq(full_address)
          expect(bike.to_coordinates.compact).to be_present
          bike.reload
          stolen_record.reload
          stolen_record.skip_geocoding = false
          Sidekiq::Testing.inline! do
            stolen_record.attributes = {street: "", city: "", zipcode: ""}
            expect(stolen_record.should_be_geocoded?).to be_truthy
            stolen_record.save
            expect(stolen_record.street).to be_nil
            expect(stolen_record.city).to be_nil
            expect(stolen_record.zipcode).to be_nil
          end
          stolen_record.reload
          bike.reload
          # Doesn't have coordinates, see geocodeable for additional information
          expect(stolen_record.to_coordinates.compact).to eq([])
          expect(stolen_record.address_hash.compact).to eq({country: "US", state: "IL"}.as_json)
          expect(stolen_record.address(force_show_address: true)).to eq "IL, US"

          expect(bike.to_coordinates.compact).to eq([])
          expect(bike.registration_address_source).to be_blank
        end
      end
      context "given a parking notification" do
        it "it still uses the stolen_record" do
          expect(bike.to_coordinates).to eq(stolen_record.to_coordinates)
          parking_notification = FactoryBot.create(:parking_notification, :in_los_angeles, bike: bike)
          bike.reload
          expect(bike.current_impound_record).to_not be_present
          expect(bike.current_parking_notification).to eq parking_notification
          expect(bike.to_coordinates).to eq(stolen_record.to_coordinates)
          expect(bike.address_set_manually).to be_falsey
          expect(bike.registration_address_source).to be_blank
          expect(bike.status).to eq "status_stolen"
          expect(bike.send(:authorization_requires_organization?)).to be_falsey
        end
      end
    end

    context "given no current_stolen_record" do
      let(:organization) { FactoryBot.create(:organization, :in_nyc) }
      let(:bike) { FactoryBot.create(:bike, creation_organization: organization) }

      it "takes location from the creation org" do
        expect(bike.reload.address_record_id).to be_blank
        expect(bike.latitude).to eq organization.latitude
        expect(bike.longitude).to eq organization.longitude
      end
    end

    context "given no creation org location" do
      let(:city) { "New York" }
      let(:zipcode) { "10011" }
      let(:address_record) { FactoryBot.create(:address_record, :new_york, street: nil) }
      let(:user) { FactoryBot.create(:user_confirmed, address_record:) }
      let(:ownership) { FactoryBot.create(:ownership, user: user, creator: user, registration_info: {zipcode: "99999", country: "US", city: city, street: "main main street"}) }
      let(:bike) { ownership.bike }
      it "takes location from the creation state" do
        bike.update(updated_at: Time.current)
        bike.reload # Set current_ownership_id
        expect(user.reload.address_record.street).to be_blank
        expect(user.address_set_manually).to be_falsey
        expect(user.to_coordinates.compact.length).to eq 2 # User still has coordinates, even though no street
        expect(bike.reload.current_ownership_id).to eq ownership.id

        ownership_address_record = bike.current_ownership.address_record
        expect(ownership_address_record[:latitude]).to be_present
        expect(ownership_address_record).to match_hash_indifferently(kind: "ownership", postal_code: "99999", street: "main main street")
        expect(bike.registration_address_source).to eq "initial_creation"
        expect(bike.to_coordinates).to eq ownership_address_record.to_coordinates
        expect(bike.address_record_id).to eq ownership_address_record.id
      end
      context "user street is present" do
        let(:user) { FactoryBot.create(:user_confirmed, :address_in_nyc, address_set_manually: true) }
        it "uses user address" do
          bike.update(updated_at: Time.current)
          bike.reload
          expect(user.reload.address_record.street).to be_present
          expect(user.address_set_manually).to be_truthy
          expect(user.to_coordinates.compact.length).to eq 2 # User has street
          expect(bike.reload.current_ownership_id).to eq ownership.id
          expect(bike.registration_address_source).to eq "user"

          bike.reload
          bike.address_set_manually = true
          bike.save

          expect(bike.reload.address_set_manually).to be_falsey # Because it's set by the user
          expect(bike.to_coordinates).to eq user.to_coordinates
          expect(bike.address_record_id).to eq user.address_record_id
        end
      end
    end

    context "with address_record" do
      let(:address_record) { FactoryBot.create(:address_record, :edmonton, kind: :bike) }
      let(:bike) { FactoryBot.create(:bike, address_record:, address_set_manually:) }
      let(:address_set_manually) { false }
      let(:coords) { address_record.reload.to_coordinates }

      it "doesn't assign from address_record" do
        expect(address_record.to_coordinates).to eq coords

        expect(bike.reload.registration_address_source).to be_blank
        expect(bike.to_coordinates).to eq([nil, nil])
        expect(bike.address_record_id).to eq address_record.id
      end

      context "with address_set_manually" do
        let(:address_set_manually) { true }

        it "assigns from address_record" do
          expect(address_record.to_coordinates).to eq coords

          expect(bike.reload.registration_address_source).to eq "bike_update"
          expect(bike.to_coordinates).to eq coords
        end
      end
    end
  end
end
