require "rails_helper"

RSpec.describe ParkingNotification, type: :model do
  describe "factory" do
    let(:parking_notification) { FactoryBot.create(:parking_notification) }
    let(:bike) { parking_notification.bike }
    it "is valid" do
      expect(parking_notification.valid?).to be_truthy
      expect(parking_notification.id).to be_present
      expect(parking_notification.owner_known?).to be_falsey
      expect(parking_notification.send_message?).to be_falsey
      expect(bike.current_parking_notification).to eq parking_notification
      expect(bike.status_abandoned?).to be_truthy
      expect(bike.status).to eq "status_abandoned"
      expect(parking_notification.organization).to be_nil
    end
    context "organized record" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:bike) { FactoryBot.create(:bike, created_at: Time.current - 2.weeks) }
      let(:parking_notification) { FactoryBot.create(:parking_notification_organized, organization: organization, bike: bike) }
      it "is valid" do
        expect(parking_notification.valid?).to be_truthy
        expect(parking_notification.owner_known?).to be_truthy
        expect(parking_notification.send_message?).to be_truthy
        expect(bike.current_parking_notification).to eq parking_notification
        expect(bike.status_abandoned?).to be_truthy
        expect(bike.status).to eq "status_abandoned"
        expect(parking_notification.organization).to eq organization
        expect(parking_notification.user.organizations).to eq([organization])
        # Test that we are just getting the orgs abandoned bikes
        FactoryBot.create(:parking_notification, user: parking_notification.user)
        organization.reload
        expect(organization.parking_notification_bikes).to eq([bike])
      end
    end
  end

  describe "initial" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:organization) { FactoryBot.create(:organization) }
    let(:parking_notification) { FactoryBot.build(:parking_notification, is_repeat: true, bike: bike, organization: organization) }
    it "is false" do
      expect(parking_notification.likely_repeat?).to be_falsey
      expect(parking_notification.can_be_repeat?).to be_falsey
      expect(parking_notification.save)
      expect(parking_notification.repeat_record?).to be_falsey
    end
    context "existing" do
      let!(:parking_notification_initial) { FactoryBot.create(:parking_notification, bike: bike, organization: initial_organization, created_at: Time.current - 1.year) }
      let(:initial_organization) { FactoryBot.create(:organization) }
      it "is false" do
        expect(parking_notification_initial.current?).to be_truthy
        expect(parking_notification_initial.initial_record?).to be_truthy
        expect(parking_notification.likely_repeat?).to be_falsey
        expect(parking_notification.can_be_repeat?).to be_falsey
        expect(parking_notification.save)
        expect(parking_notification.repeat_record?).to be_falsey
      end
      context "same organization" do
        let(:initial_organization) { organization }
        it "can be assigned" do
          expect(parking_notification.potential_initial_record).to eq parking_notification_initial
          expect(parking_notification.likely_repeat?).to be_falsey
          expect(parking_notification.can_be_repeat?).to be_truthy
          expect(parking_notification.save)
          expect(parking_notification.repeat_record?).to be_truthy
          expect(parking_notification.initial_record).to eq parking_notification_initial
          expect(parking_notification_initial.repeat_records.pluck(:id)).to match_array([parking_notification.id])

          parking_notification_initial.update_attribute :retrieved_at, Time.current
          parking_notification_initial.reload
          parking_notification.reload
          expect(parking_notification_initial.repeat_records.pluck(:id)).to match_array([parking_notification.id])
          expect(parking_notification.likely_repeat?).to be_falsey
          expect(parking_notification.can_be_repeat?).to be_truthy
          expect(parking_notification.potential_initial_record).to eq parking_notification_initial
        end
        context "additional parking_notification" do
          let!(:parking_notification2) { FactoryBot.create(:parking_notification, bike: bike, organization: initial_organization, created_at: Time.current - 1.week, initial_record: parking_notification_initial) }
          it "can be assigned" do
            expect(parking_notification.likely_repeat?).to be_truthy
            expect(parking_notification.can_be_repeat?).to be_truthy
            expect(parking_notification.save)
            expect(parking_notification.repeat_record?).to be_truthy
            expect(parking_notification.initial_record).to eq parking_notification_initial
            expect(parking_notification2.initial_record).to eq parking_notification_initial
            expect(parking_notification_initial.repeat_records.pluck(:id)).to match_array([parking_notification.id, parking_notification2.id])
            expect(parking_notification_initial.repeat_number).to eq 0
            expect(parking_notification2.repeat_number).to eq 1
            expect(parking_notification.repeat_number).to eq 2
          end
        end
      end
    end
  end

  describe "address" do
    # Copies StolenRecord, needs to be moved to a concern
    let(:country) { Country.create(name: "Neverland", iso: "NEVVVV") }
    let(:state) { State.create(country_id: country.id, name: "BullShit", abbreviation: "XXX") }
    it "creates an address" do
      parking_notification = ParkingNotification.new(street: "2200 N Milwaukee Ave",
                                             city: "Chicago",
                                             hide_address: true,
                                             state_id: state.id,
                                             zipcode: "60647",
                                             country_id: country.id)
      expect(parking_notification.address).to eq("Chicago, XXX 60647, NEVVVV")
      expect(parking_notification.address(force_show_address: true)).to eq("2200 N Milwaukee Ave, Chicago, XXX 60647, NEVVVV")
      parking_notification.hide_address = false
      expect(parking_notification.address).to eq("2200 N Milwaukee Ave, Chicago, XXX 60647, NEVVVV")
    end
    it "is ok with missing information" do
      parking_notification = ParkingNotification.new(street: "2200 N Milwaukee Ave",
                                             zipcode: "60647",
                                             hide_address: true,
                                             country_id: country.id)
      expect(parking_notification.address).to eq("60647, NEVVVV")
      parking_notification.hide_address = false
      expect(parking_notification.address).to eq("2200 N Milwaukee Ave, 60647, NEVVVV")
    end
    it "returns even if no country" do
      parking_notification = ParkingNotification.new(street: "302666 Richmond Blvd")
      expect(parking_notification.address).to eq parking_notification.street
    end
  end

  describe "set_calculated_attributes" do
    context "geolocated" do
      let(:ownership) { FactoryBot.create(:ownership, owner_email: "stuff@stuff.com") }
      let(:bike) { ownership.bike }
      let(:parking_notification) { FactoryBot.build(:parking_notification, bike: bike, latitude: nil, longitude: nil) }
      it "sets the email from the bike, fails without location" do
        expect(bike.owner_email).to eq "stuff@stuff.com"
        parking_notification.save
        expect(parking_notification.valid?).to be_falsey
        expect(parking_notification.errors.messages.to_s).to match(/address/)
        expect(parking_notification.kind_humanized).to eq "Abandoned"
      end
    end
    context "no address" do
      let!(:state) { State.find_or_create_by(FactoryBot.attributes_for(:state_new_york)) }
      let!(:country) { Country.united_states }
      let(:parking_notification) { FactoryBot.build(:parking_notification, latitude: default_location[:latitude], longitude: default_location[:longitude]) }
      it "sets address" do
        parking_notification.save
        expect(parking_notification.state).to eq state
        expect(parking_notification.country).to eq country
        expect(parking_notification.address).to be_present
        expect(parking_notification.valid?).to be_truthy
        expect(parking_notification.id).to be_present
      end
    end

    context "address set" do
      let(:latitude) { 41.9202384 }
      let(:longitude) { -87.7158185 }
      let(:parking_notification) { FactoryBot.build(:parking_notification, latitude: nil, longitude: nil, street: "3554 W Shakespeare Ave, 60647") }
      include_context :geocoder_real
      it "falls back to address" do
        VCR.use_cassette("parking_notification-address_lookup") do
          parking_notification.save
          expect(parking_notification.latitude).to eq latitude
          expect(parking_notification.longitude).to eq longitude
          expect(parking_notification.valid?).to be_truthy
          expect(parking_notification.id).to be_present
        end
      end
      context "use_entered_address and lat/long set" do
        it "uses address" do
          VCR.use_cassette("parking_notification-address_lookup") do
            parking_notification.update_attributes(use_entered_address: true, latitude: 34.05223, longitude: -118.24368)
            expect(parking_notification.latitude).to eq latitude
            expect(parking_notification.longitude).to eq longitude
            expect(parking_notification.valid?).to be_truthy
            expect(parking_notification.id).to be_present
          end
        end
      end
    end
  end
end
