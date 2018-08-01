require "spec_helper"

RSpec.describe OrganizationMessage, type: :model do
  describe "factory" do
    let(:organization_message) { FactoryGirl.create(:organization_message) }
    it "is valid" do
      expect(organization_message.id).to be_present
    end
  end

  describe "set_calculated_attributes" do
    context "geolocated" do
      include_context :geocoder_default_location
      let(:ownership) { FactoryGirl.create(:ownership, owner_email: "stuff@stuff.com") }
      let(:bike) { ownership.bike }
      let(:organization_message) { FactoryGirl.build(:organization_message, email: nil, kind: :geolocated, bike: bike, latitude: nil, longitude: nil) }
      it "sets the email from the bike" do
        expect(bike.owner_email).to eq "stuff@stuff.com"
        organization_message.save
        expect(organization_message.email).to eq "stuff@stuff.com"
        expect(organization_message.valid?).to be_falsey
        expect(organization_message.errors.messages.to_s).to match(/location/)
      end
    end
  end
end
