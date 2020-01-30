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

  describe "set_calculated_attributes" do
    context "geolocated" do
      let(:ownership) { FactoryBot.create(:ownership, owner_email: "stuff@stuff.com") }
      let(:bike) { ownership.bike }
      let(:abandoned_record) { FactoryBot.build(:abandoned_record, bike: bike, latitude: nil, longitude: nil, address: nil) }
      it "sets the email from the bike, fails without location" do
        expect(bike.owner_email).to eq "stuff@stuff.com"
        abandoned_record.save
        expect(abandoned_record.valid?).to be_falsey
        expect(abandoned_record.errors.messages.to_s).to match(/address/)
      end
    end
    context "no address" do
      let(:abandoned_record) { FactoryBot.build(:abandoned_record, latitude: default_location[:latitude], longitude: default_location[:longitude]) }
      it "sets address" do
        abandoned_record.save
        expect(abandoned_record.address).to be_present
        expect(abandoned_record.valid?).to be_truthy
        expect(abandoned_record.id).to be_present
      end
    end
    context "no location, but address" do
      let(:latitude) { 41.9202384 }
      let(:longitude) { -87.7158185 }
      let(:abandoned_record) { FactoryBot.build(:abandoned_record, latitude: nil, longitude: nil, address: "3554 W Shakespeare Ave, 60647") }
      include_context :geocoder_real
      it "sets location" do
        VCR.use_cassette("abandoned_record-address_lookup") do
          abandoned_record.save
          expect(abandoned_record.latitude).to eq latitude
          expect(abandoned_record.longitude).to eq longitude
          expect(abandoned_record.valid?).to be_truthy
          expect(abandoned_record.id).to be_present
        end
      end
    end
    context "with only one or the other attribute (in case of geocoder fail)" do
      let(:bike) { FactoryBot.create(:bike) }
      let(:user) { FactoryBot.create(:user) }
      let(:abandoned_record_address) { FactoryBot.build(:abandoned_record, bike: bike, user: user, latitude: nil, longitude: nil, address: "Some cool place") }
      let(:abandoned_record_position) { FactoryBot.build(:abandoned_record, bike: bike, user: user, address: nil) }
      it "still creates" do
        allow(Geohelper).to receive(:reverse_geocode) { nil }
        allow(Geohelper).to receive(:coordinates_for) { nil }
        expect(abandoned_record_address.save).to be_truthy
        expect(abandoned_record_position.save).to be_truthy
        abandoned_record_address.reload
        abandoned_record_position.reload

        expect(abandoned_record_position.latitude).to be_present
        expect(abandoned_record_position.longitude).to be_present
        expect(abandoned_record_position.address).to be_blank

        expect(abandoned_record_address.latitude).to be_blank
        expect(abandoned_record_address.longitude).to be_blank
        expect(abandoned_record_address.address).to be_present
      end
    end
  end
end
