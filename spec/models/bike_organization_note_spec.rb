require "rails_helper"

RSpec.describe BikeOrganizationNote, type: :model do
  describe "factory" do
    let(:bike_organization_note) { FactoryBot.create(:bike_organization_note) }

    it "is valid" do
      expect(bike_organization_note).to be_valid
      expect(bike_organization_note.body).to be_present
      expect(bike_organization_note.user).to be_present
      expect(bike_organization_note.bike_organization).to be_present
    end

    context "with bike transient" do
      let(:bike) { FactoryBot.create(:bike_organized) }
      let(:bike_organization_note) { FactoryBot.create(:bike_organization_note, bike:) }

      it "uses the bike's existing bike_organization" do
        expect(bike.bike_organizations.count).to eq 1
        expect(bike_organization_note.bike_organization).to eq bike.bike_organizations.first
      end
    end
  end
end
