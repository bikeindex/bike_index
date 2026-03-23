require "rails_helper"

RSpec.describe BikeOrganizationNote, type: :model do
  describe "factory" do
    let(:bike_organization_note) { FactoryBot.create(:bike_organization_note) }

    it "is valid" do
      expect(bike_organization_note).to be_valid
      expect(bike_organization_note.body).to be_present
      expect(bike_organization_note.user).to be_present
      expect(bike_organization_note.bike).to be_present
      expect(bike_organization_note.organization).to be_present
      # Verify that we aren't tracking versions by default
      expect(bike_organization_note.versions.count).to eq 0
    end

    context "with bike transient" do
      let(:bike) { FactoryBot.create(:bike_organized) }
      let(:bike_organization_note) { FactoryBot.create(:bike_organization_note, bike:) }

      it "uses the bike's existing organization" do
        expect(bike.organizations.count).to eq 1
        expect(bike_organization_note.organization).to eq bike.organizations.first
      end
    end
  end

  describe "versioning" do
    include_context :with_paper_trail

    let(:bike_organization_note) { FactoryBot.create(:bike_organization_note, body: "Example note") }

    it "creates a version on create" do
      expect(bike_organization_note.versions.count).to eq 1
      version = bike_organization_note.versions.last
      expect(version.event).to eq "create"
      target_changes = {
        body: [nil, "Example note"],
        bike_id: [nil, bike_organization_note.bike_id]
      }
      expect(version.object_changes).to eq target_changes.as_json
    end

    context "on update" do
      let(:target_changes) { {body: ["Example note", "updated body"]} }
      let(:target_object) do
        {id: bike_organization_note.id, body: "Example note", bike_id: bike_organization_note.bike_id,
         user_id: bike_organization_note.user_id, organization_id: bike_organization_note.organization_id}
      end
      it "creates a version" do
        bike_organization_note.update!(body: "updated body")
        expect(bike_organization_note.versions.count).to eq 2
        version = bike_organization_note.versions.last
        expect(version.event).to eq "update"
        expect(version.object_changes).to eq target_changes.as_json
        expect(version.object.except("created_at", "updated_at")).to eq target_object.as_json
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
