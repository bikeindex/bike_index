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
      expect(parking_notification.address(override_show_address: true)).to eq("2200 N Milwaukee Ave, Chicago, XXX 60647, NEVVVV")
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
    it "returns nil if there is no country" do
      parking_notification = ParkingNotification.new(street: "302666 Richmond Blvd")
      expect(parking_notification.address).to be_nil
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
        expect(parking_notification.kind_humanized).to eq "appears abandoned"
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
  # TODO: location refactor -
  #   context "no location, but address" do
  #     let(:latitude) { 41.9202384 }
  #     let(:longitude) { -87.7158185 }
  #     let(:parking_notification) { FactoryBot.build(:parking_notification, latitude: nil, longitude: nil, street: "3554 W Shakespeare Ave, 60647") }
  #     include_context :geocoder_real
  #     it "sets location" do
  #       VCR.use_cassette("parking_notification-address_lookup") do
  #         parking_notification.save
  #         expect(parking_notification.latitude).to eq latitude
  #         expect(parking_notification.longitude).to eq longitude
  #         expect(parking_notification.valid?).to be_truthy
  #         expect(parking_notification.id).to be_present
  #       end
  #     end
  #   end
  #   context "with only one or the other attribute (in case of geocoder fail)" do
  #     let(:bike) { FactoryBot.create(:bike) }
  #     let(:user) { FactoryBot.create(:user) }
  #     let(:parking_notification_address) { FactoryBot.build(:parking_notification, bike: bike, user: user, latitude: nil, longitude: nil, street: "Some cool place") }
  #     let(:parking_notification_position) { FactoryBot.build(:parking_notification, bike: bike, user: user, address: nil) }
  #     it "still creates" do
  #       allow(Geohelper).to receive(:reverse_geocode) { nil }
  #       allow(Geohelper).to receive(:coordinates_for) { nil }
  #       expect(parking_notification_address.save).to be_truthy
  #       expect(parking_notification_position.save).to be_truthy
  #       parking_notification_address.reload
  #       parking_notification_position.reload

  #       expect(parking_notification_position.latitude).to be_present
  #       expect(parking_notification_position.longitude).to be_present
  #       expect(parking_notification_position.address).to be_blank

  #       expect(parking_notification_address.latitude).to be_blank
  #       expect(parking_notification_address.longitude).to be_blank
  #       expect(parking_notification_address.address).to be_present
  #     end
  #   end
  end
end
