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
      before { stolen_record.skip_geocoding = false }
      it "takes location from the current stolen record" do
        expect(stolen_record.street).to eq street_address
        expect(stolen_record.address(force_show_address: true)).to eq(full_address)
        expect(stolen_record.address).to eq(abbr_address)

        bike.reload
        # Ensure we aren't geocoding ;)
        allow(bike).to receive(:bike_index_geocode) { fail "should not have called geocoding" }
        stolen_record.save
        bike.save
        expect(StolenRecord.unscoped.where(bike_id: bike.id).count).to eq 1

        expect(bike.to_coordinates).to eq(stolen_record.to_coordinates)
        expect(bike.city).to eq(stolen_record.city)
        expect(bike.street).to be_present
        expect(bike.zipcode).to eq(stolen_record.zipcode)
        expect(bike.address).to eq(full_address)
        expect(bike.country).to eq(stolen_record.country)
      end
      context "removing location from the stolen_record" do
        include_context :geocoder_real
        # When displaying searches for stolen bikes, it's critical we honor the stolen record's data
        # ... or else unexpected things happen
        it "blanks the location on the bike" do
          expect(stolen_record.address(force_show_address: true)).to eq(full_address)
          expect(bike.address).to eq "1300 W 14th Pl, Chicago, IL 60608, US"
          allow(bike).to receive(:bike_index_geocode) { fail "should not have called geocoding" }
          bike.reload
          stolen_record.reload
          # stolen_record.skip_geocoding = false
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

          expect(bike.address_hash).to eq({country: "US", state: "IL", street: nil, city: nil, zipcode: nil, latitude: nil, longitude: nil}.as_json)
          expect(bike.to_coordinates.compact).to eq([])
          expect(bike.should_be_geocoded?).to be_falsey
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
          expect(bike.address_hash).to eq stolen_record.address_hash
          expect(bike.address_set_manually).to be_falsey
          expect(bike.registration_address_source).to be_blank
          expect(bike.status).to eq "status_stolen"
          expect(bike.send(:authorization_requires_organization?)).to be_falsey
        end
      end
    end

    context "given no current_stolen_record" do
      it "takes location from the creation org" do
        org = FactoryBot.create(:organization, :in_nyc)
        bike = FactoryBot.build(:bike, creation_organization: org)

        bike.attributes = described_class.location_attrs(bike)

        expect(bike.city).to eq("New York")
        expect(bike.zipcode).to eq("10011")
        expect(bike.country).to eq(usa)
        expect(bike.street).to be_present
      end
      context "with a blank street" do
        let(:bike) { FactoryBot.create(:bike, street: "  ") }
        it "is nil" do
          expect(bike.reload.street).to be_nil
        end
      end
    end

    context "given no creation org location" do
      let(:city) { "New York" }
      let(:zipcode) { "10011" }
      let(:address_record) { FactoryBot.create(:address_record, :new_york) }
      let(:user) { FactoryBot.create(:user_confirmed, address_record:) }
      let(:ownership) { FactoryBot.create(:ownership, user: user, creator: user, registration_info: {zipcode: "99999", country: "US", city: city, street: "main main street"}) }
      let(:bike) { ownership.bike }
      it "takes location from the creation state" do
        bike.update(updated_at: Time.current)
        bike.reload # Set current_ownership_id
        expect(user.reload.street).to be_blank
        expect(user.address_set_manually).to be_falsey
        expect(user.to_coordinates.compact.length).to eq 2 # User still has coordinates, even though no street
        expect(bike.reload.current_ownership_id).to eq ownership.id
        expect(bike.current_ownership.address_hash[:latitude]).to be_blank
        expect(bike.registration_address_source).to eq "initial_creation"
        expect(bike.registration_address(true)["zipcode"]).to eq "99999"

        bike.reload
        bike.skip_geocoding = false
        expect(bike.skip_geocoding).to be_falsey

        expect(bike.city).to eq(city)
        expect(bike.zipcode).to eq("99999")
        expect(bike.country).to eq(usa)
        expect(bike.street).to eq "main main street"
      end
      context "user street is present" do
        let(:user) { FactoryBot.create(:user_confirmed, :in_nyc, address_set_manually: true) }
        it "uses user address" do
          bike.update(updated_at: Time.current)
          bike.reload
          expect(user.reload.street).to be_present
          expect(user.address_set_manually).to be_truthy
          expect(user.to_coordinates.compact.length).to eq 2 # User still has coordinates, even though no street
          expect(bike.reload.current_ownership_id).to eq ownership.id
          expect(bike.registration_address_source).to eq "user"

          bike.reload
          bike.address_set_manually = true
          bike.street = nil
          bike.skip_geocoding = false
          bike.save
          expect(bike.skip_geocoding).to be_truthy

          expect(bike.address_hash).to eq user.address_hash_legacy
          expect(bike.street).to eq user.street
          expect(bike.address_set_manually).to be_falsey # Because it's set by the user
        end
      end
    end
  end
end
