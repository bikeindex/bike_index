require "spec_helper"

RSpec.describe OrganizationEmail, type: :model do
  describe "factory" do
    let(:organization_email) { FactoryGirl.create(:organization_email) }
    it "is valid" do
      expect(organization_email.id).to be_present
    end
  end

  describe "set_calculated_attributes" do
    context "geolocated" do
      include_context :geocoder_default_location
      let(:ownership) { FactoryGirl.create(:ownership, owner_email: "stuff@stuff.com") }
      let(:bike) { ownership.bike }
      let(:organization_email) { FactoryGirl.build(:organization_email, email: nil, kind: :geolocated, bike: bike, latitude: nil, longitude: nil) }
      it "sets the email from the bike" do
        expect(bike.owner_email).to eq "stuff@stuff.com"
        organization_email.save
        expect(organization_email.email).to eq "stuff@stuff.com"
        expect(organization_email.valid?).to be_falsey
        expect(organization_email.errors.messages.to_s).to match(/location/)
      end
    end
  end
end
