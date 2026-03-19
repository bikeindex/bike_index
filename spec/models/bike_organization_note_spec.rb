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

  describe "versioning" do
    include_context :with_paper_trail

    let(:bike_organization_note) { FactoryBot.create(:bike_organization_note) }

    it "creates a version on create" do
      expect(bike_organization_note.versions.count).to eq 1
      expect(bike_organization_note.versions.last.event).to eq "create"
    end

    context "on update" do
      it "creates a version" do
        bike_organization_note.update!(body: "updated body")
        expect(bike_organization_note.versions.count).to eq 2
        expect(bike_organization_note.versions.last.event).to eq "update"
      end
    end

    context "on destroy" do
      it "creates a version" do
        bike_organization_note.destroy!
        expect(PaperTrail::Version.last.event).to eq "destroy"
        expect(PaperTrail::Version.last.item_id).to eq bike_organization_note.id
      end
    end
  end
end
