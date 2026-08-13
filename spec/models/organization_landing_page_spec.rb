require "rails_helper"

RSpec.describe OrganizationLandingPage, type: :model do
  describe "factory" do
    let(:organization_landing_page) { FactoryBot.create(:organization_landing_page) }

    it "is valid" do
      expect(organization_landing_page).to be_valid
      expect(organization_landing_page.body).to be_present
      expect(organization_landing_page.enabled).to be_falsey
      expect(organization_landing_page.organization.organization_landing_page).to eq organization_landing_page
    end

    context "with a blank body" do
      let(:organization_landing_page) { FactoryBot.create(:organization_landing_page, body: "  ") }

      it "stores nil" do
        expect(organization_landing_page.body).to be_nil
      end
    end
  end

  describe "uniqueness" do
    let(:organization_landing_page) { FactoryBot.create(:organization_landing_page) }

    it "permits one landing page per organization" do
      duplicate = described_class.new(organization_id: organization_landing_page.organization_id)
      expect(duplicate).to_not be_valid
      expect(duplicate.errors.full_messages.join).to match(/already been taken/i)
    end
  end

  describe "versioning" do
    include_context :with_paper_trail

    let(:organization_landing_page) { FactoryBot.create(:organization_landing_page, body: "<p>Original</p>") }

    it "creates a version on create" do
      expect(organization_landing_page.versions.count).to eq 1
      version = organization_landing_page.versions.last
      expect(version.event).to eq "create"
      expect(version.object_changes)
        .to eq({body: [nil, "<p>Original</p>"], organization_id: [nil, organization_landing_page.organization_id]}.as_json)
    end

    context "on update" do
      it "creates a version" do
        organization_landing_page.update!(body: "<p>Updated</p>")
        expect(organization_landing_page.versions.count).to eq 2
        version = organization_landing_page.versions.last
        expect(version.event).to eq "update"
        expect(version.object_changes).to eq({body: ["<p>Original</p>", "<p>Updated</p>"]}.as_json)
        expect(version.reify.body).to eq "<p>Original</p>"
      end

      context "enabling" do
        it "creates a version" do
          organization_landing_page.update!(enabled: true)
          expect(organization_landing_page.versions.count).to eq 2
          expect(organization_landing_page.versions.last.object_changes).to eq({enabled: [false, true]}.as_json)
        end
      end
    end

    context "on destroy" do
      it "snapshots the whole record, so it can be restored" do
        organization_landing_page.update!(enabled: true)
        organization_landing_page.destroy!
        version = PaperTrail::Version.last
        expect(version.event).to eq "destroy"
        expect(version.item_id).to eq organization_landing_page.id
        # only: doesn't narrow the destroy snapshot - object holds every column
        expect(version.reify.enabled).to be_truthy
        expect(version.reify.organization_id).to eq organization_landing_page.organization_id
      end
    end
  end
end
