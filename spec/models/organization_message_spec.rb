require "spec_helper"

RSpec.describe OrganizationMessage, type: :model do
  describe "factory" do
    let(:organization_message) { FactoryGirl.create(:organization_message) }
    it "is valid" do
      expect(organization_message.valid?).to be_truthy
      expect(organization_message.id).to be_present
    end
  end

  describe "set_calculated_attributes" do
    include_context :geocoder_default_location
    context "geolocated" do
      let(:ownership) { FactoryGirl.create(:ownership, owner_email: "stuff@stuff.com") }
      let(:bike) { ownership.bike }
      let(:organization_message) { FactoryGirl.build(:organization_message, email: nil, kind: :geolocated, bike: bike, latitude: nil, longitude: nil, address: nil) }
      it "sets the email from the bike, fails without location" do
        expect(bike.owner_email).to eq "stuff@stuff.com"
        organization_message.save
        expect(organization_message.email).to eq "stuff@stuff.com"
        expect(organization_message.valid?).to be_falsey
        expect(organization_message.errors.messages.to_s).to match(/location/)
        expect(EmailOrganizationMessageWorker.jobs.count).to eq 0
      end
    end
    context "no address" do
      let(:organization_message) { FactoryGirl.build(:organization_message, kind: :geolocated, latitude: default_location[:latitude], longitude: default_location[:longitude]) }
      it "sets address" do
        organization_message.save
        expect(organization_message.address).to be_present
        expect(organization_message.valid?).to be_truthy
        expect(organization_message.id).to be_present
        expect(EmailOrganizationMessageWorker.jobs.count).to eq 1
      end
    end
    context "no location, but address" do
      let(:latitude) { 41.9202384 }
      let(:longitude) { -87.7158185 }
      let(:organization_message) { FactoryGirl.build(:organization_message, kind: :geolocated, latitude: nil, longitude: nil, address: "3554 W Shakespeare Ave, 60647") }
      it "sets location" do
        Geocoder.configure(lookup: :google, use_https: true)
        VCR.use_cassette("organization_message-address_lookup") do
          organization_message.save
          expect(organization_message.latitude).to eq latitude
          expect(organization_message.longitude).to eq longitude
          expect(organization_message.valid?).to be_truthy
          expect(organization_message.id).to be_present
          expect(EmailOrganizationMessageWorker.jobs.count).to eq 1
        end
      end
    end
  end
end
