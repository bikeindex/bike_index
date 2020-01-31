require "rails_helper"

RSpec.describe AbandonedRecord, type: :model do
  describe "factory" do
    let(:abandoned_record) { FactoryBot.create(:abandoned_record) }
    let(:bike) { abandoned_record.bike }
    it "is valid" do
      expect(abandoned_record.valid?).to be_truthy
      expect(abandoned_record.id).to be_present
      expect(abandoned_record.owner_known?).to be_falsey
      expect(abandoned_record.send_message?).to be_falsey
      expect(bike.current_initial_abandoned_record).to eq abandoned_record
      expect(bike.state_abandoned?).to be_truthy
      expect(bike.state).to eq "state_abandoned"
      expect(abandoned_record.organization).to be_nil
    end
    context "organized record" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:bike) { FactoryBot.create(:bike, created_at: Time.current - 2.weeks) }
      let(:abandoned_record) { FactoryBot.create(:abandoned_record_organized, organization: organization, bike: bike) }
      it "is valid" do
        expect(abandoned_record.valid?).to be_truthy
        expect(abandoned_record.owner_known?).to be_truthy
        expect(abandoned_record.send_message?).to be_truthy
        expect(bike.current_initial_abandoned_record).to eq abandoned_record
        expect(bike.state_abandoned?).to be_truthy
        expect(bike.state).to eq "state_abandoned"
        expect(abandoned_record.organization).to eq organization
        expect(abandoned_record.user.organizations).to eq([organization])
        # Test that we are just getting the orgs abandoned bikes
        FactoryBot.create(:abandoned_record, user: abandoned_record.user)
        organization.reload
        expect(organization.abandoned_bikes).to eq([bike])
      end
    end
  end

  describe "address" do
    # Copies StolenRecord, needs to be moved to a concern
    let(:country) { Country.create(name: "Neverland", iso: "NEVVVV") }
    let(:state) { State.create(country_id: country.id, name: "BullShit", abbreviation: "XXX") }
    it "creates an address" do
      abandoned_record = AbandonedRecord.new(street: "2200 N Milwaukee Ave",
                                             city: "Chicago",
                                             hide_address: true,
                                             state_id: state.id,
                                             zipcode: "60647",
                                             country_id: country.id)
      expect(abandoned_record.address).to eq("Chicago, XXX, 60647, NEVVVV")
      expect(abandoned_record.address(override_show_address: true)).to eq("2200 N Milwaukee Ave, Chicago, XXX, 60647, NEVVVV")
      abandoned_record.hide_address = false
      expect(abandoned_record.address).to eq("2200 N Milwaukee Ave, Chicago, XXX, 60647, NEVVVV")
    end
    it "is ok with missing information" do
      abandoned_record = AbandonedRecord.new(street: "2200 N Milwaukee Ave",
                                             zipcode: "60647",
                                             hide_address: true,
                                             country_id: country.id)
      expect(abandoned_record.address).to eq("60647, NEVVVV")
      abandoned_record.hide_address = false
      expect(abandoned_record.address).to eq("2200 N Milwaukee Ave, 60647, NEVVVV")
    end
    it "returns nil if there is no country" do
      abandoned_record = AbandonedRecord.new(street: "302666 Richmond Blvd")
      expect(abandoned_record.address).to be_nil
    end
  end

  describe "set_calculated_attributes" do
    context "geolocated" do
      let(:ownership) { FactoryBot.create(:ownership, owner_email: "stuff@stuff.com") }
      let(:bike) { ownership.bike }
      let(:abandoned_record) { FactoryBot.build(:abandoned_record, bike: bike, latitude: nil, longitude: nil) }
      it "sets the email from the bike, fails without location" do
        expect(bike.owner_email).to eq "stuff@stuff.com"
        abandoned_record.save
        expect(abandoned_record.valid?).to be_falsey
        expect(abandoned_record.errors.messages.to_s).to match(/address/)
      end
    end
    context "no address" do
      let!(:state) { State.find_or_create_by(FactoryBot.attributes_for(:state_new_york)) }
      let!(:country) { Country.united_states }
      let(:abandoned_record) { FactoryBot.build(:abandoned_record, latitude: default_location[:latitude], longitude: default_location[:longitude]) }
      it "sets address" do
        abandoned_record.save
        expect(abandoned_record.state).to eq state
        expect(abandoned_record.country).to eq country
        expect(abandoned_record.address).to be_present
        expect(abandoned_record.valid?).to be_truthy
        expect(abandoned_record.id).to be_present
      end
    end
  # TODO:
  #   context "no location, but address" do
  #     let(:latitude) { 41.9202384 }
  #     let(:longitude) { -87.7158185 }
  #     let(:abandoned_record) { FactoryBot.build(:abandoned_record, latitude: nil, longitude: nil, street: "3554 W Shakespeare Ave, 60647") }
  #     include_context :geocoder_real
  #     it "sets location" do
  #       VCR.use_cassette("abandoned_record-address_lookup") do
  #         abandoned_record.save
  #         expect(abandoned_record.latitude).to eq latitude
  #         expect(abandoned_record.longitude).to eq longitude
  #         expect(abandoned_record.valid?).to be_truthy
  #         expect(abandoned_record.id).to be_present
  #       end
  #     end
  #   end
  #   context "with only one or the other attribute (in case of geocoder fail)" do
  #     let(:bike) { FactoryBot.create(:bike) }
  #     let(:user) { FactoryBot.create(:user) }
  #     let(:abandoned_record_address) { FactoryBot.build(:abandoned_record, bike: bike, user: user, latitude: nil, longitude: nil, street: "Some cool place") }
  #     let(:abandoned_record_position) { FactoryBot.build(:abandoned_record, bike: bike, user: user, address: nil) }
  #     it "still creates" do
  #       allow(Geohelper).to receive(:reverse_geocode) { nil }
  #       allow(Geohelper).to receive(:coordinates_for) { nil }
  #       expect(abandoned_record_address.save).to be_truthy
  #       expect(abandoned_record_position.save).to be_truthy
  #       abandoned_record_address.reload
  #       abandoned_record_position.reload

  #       expect(abandoned_record_position.latitude).to be_present
  #       expect(abandoned_record_position.longitude).to be_present
  #       expect(abandoned_record_position.address).to be_blank

  #       expect(abandoned_record_address.latitude).to be_blank
  #       expect(abandoned_record_address.longitude).to be_blank
  #       expect(abandoned_record_address.address).to be_present
  #     end
  #   end
  end
end
