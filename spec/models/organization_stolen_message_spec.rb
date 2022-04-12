require "rails_helper"

RSpec.describe OrganizationStolenMessage, type: :model do
  describe "calculated_attributes" do
    let(:organization) { FactoryBot.create(:organization, kind: "law_enforcement") }
    let(:organization_stolen_message) { OrganizationStolenMessage.create(organization_id: organization.id) }
    it "uses attributes" do
      expect(organization_stolen_message.reload.organization_id).to eq organization.id
      expect(organization_stolen_message.kind).to eq "area"
      organization_stolen_message.update(enabled: true, message: "  ", kind: "association")
      expect(organization_stolen_message.enabled).to be_falsey
      expect(organization_stolen_message.message).to eq nil
      expect(organization_stolen_message.latitude).to be_blank
    end
    context "organization with location" do
      let(:organization) { FactoryBot.create(:organization, :in_nyc, kind: "bike_manufacturer", search_radius_miles: 94) }
      it "uses location" do
        expect(organization_stolen_message.reload.latitude).to eq organization.location_latitude
        expect(organization_stolen_message.longitude).to eq organization.location_longitude
        expect(organization_stolen_message.radius_miles).to eq 94
        expect(organization_stolen_message.kind).to eq "association"
        expect(organization_stolen_message.enabled).to be_falsey
        organization_stolen_message.update(enabled: true, message: "  Something\n<strong> PARTy</strong>  ", radius_miles: 12, latitude: 22, longitude: 22)
        expect(organization_stolen_message.reload.latitude).to eq organization.location_latitude
        expect(organization_stolen_message.longitude).to eq organization.location_longitude
        expect(organization_stolen_message.message).to eq "Something PARTy"
        expect(organization_stolen_message.radius_miles).to eq 12
        expect(organization_stolen_message.enabled).to be_truthy
      end
    end
    context "overly long message" do
      let(:target) { "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cill" }
      it "truncates" do
        organization_stolen_message.update(enabled: true, message: " #{target} um dolore eu fugiat nulla pariatur.")
        expect(organization_stolen_message.reload.enabled).to be_falsey
        expect(organization_stolen_message.message).to eq target
      end
    end
  end
end
