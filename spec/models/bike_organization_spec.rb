require "rails_helper"

RSpec.describe BikeOrganization, type: :model do
  describe "can_edit_claimed" do
    let(:bike_organization) { BikeOrganization.new }
    it "assigns correctly" do
      expect(bike_organization.can_edit_claimed).to be_truthy
      bike_organization.can_edit_claimed = false
      expect(bike_organization.can_edit_claimed).to be_falsey
      expect(bike_organization.can_not_edit_claimed).to be_truthy
    end
  end

  describe "delete_bike_organization_note" do
    let(:bike_organization) { FactoryBot.create(:bike_organization) }
    let!(:bike_organization_note) { FactoryBot.create(:bike_organization_note, bike: bike_organization.bike, organization: bike_organization.organization) }

    it "deletes the note when bike_organization is destroyed" do
      expect(BikeOrganizationNote.where(bike_id: bike_organization.bike_id, organization_id: bike_organization.organization_id).count).to eq 1
      bike_organization.destroy
      expect(BikeOrganizationNote.where(bike_id: bike_organization.bike_id, organization_id: bike_organization.organization_id).count).to eq 0
    end
  end
end
