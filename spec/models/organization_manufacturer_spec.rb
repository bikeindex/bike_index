require "rails_helper"

RSpec.describe OrganizationManufacturer, type: :model do
  describe "factory" do
    let(:organization_manufacturer) { FactoryBot.create(:organization_manufacturer) }
    it "is valid" do
      expect(organization_manufacturer).to be_valid
    end
  end

  describe "organizations_can_view_counts" do
    let(:manufacturer) { FactoryBot.create(:manufacturer) }
    let!(:organization_manufacturer) { FactoryBot.create(:organization_manufacturer, manufacturer: manufacturer) }
    let!(:organization_manufacturer2) { FactoryBot.create(:organization_manufacturer, manufacturer: manufacturer, can_view_counts: true) }
    let!(:manufacturer_organization) { FactoryBot.create(:organization, manufacturer: manufacturer) }
    it "associates" do
      expect(organization_manufacturer.manufacturer_organization&.id).to eq manufacturer_organization.id
      expect(manufacturer_organization.organization_view_counts.pluck(:id)).to eq([organization_manufacturer2.organization_id])
    end
  end
end
