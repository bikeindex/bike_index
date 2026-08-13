require "rails_helper"

RSpec.describe OrganizationLandingPage, type: :model do
  describe "factory" do
    let(:organization_landing_page) { FactoryBot.create(:organization_landing_page) }

    it "is valid" do
      expect(organization_landing_page).to be_valid
      expect(organization_landing_page.body).to be_present
      expect(organization_landing_page.organization.landing_page_body?).to be_truthy
      # Verify that we aren't tracking versions by default
      expect(organization_landing_page.versions.count).to eq 0
    end

    context "with a blank body" do
      let(:organization_landing_page) { FactoryBot.create(:organization_landing_page, body: "  ") }

      it "stores nil" do
        expect(organization_landing_page.body).to be_nil
        expect(organization_landing_page.organization.landing_page_body?).to be_falsey
      end
    end
  end

  describe "for" do
    let(:organization) { FactoryBot.create(:organization) }

    it "creates one landing page per organization" do
      expect { described_class.for(organization) }.to change(described_class, :count).by 1
      expect { described_class.for(organization) }.to change(described_class, :count).by 0
      expect(organization.reload.organization_landing_page).to eq described_class.for(organization)
    end
  end

  describe "versioning" do
    include_context :with_paper_trail

    let(:organization_landing_page) { FactoryBot.create(:organization_landing_page, body: "<p>Original</p>") }

    it "creates a version on create" do
      expect(organization_landing_page.versions.count).to eq 1
      version = organization_landing_page.versions.last
      expect(version.event).to eq "create"
      expect(version.object_changes).to eq({body: [nil, "<p>Original</p>"]}.as_json)
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
    end

    context "on destroy" do
      it "creates a version" do
        organization_landing_page.destroy!
        expect(PaperTrail::Version.last.event).to eq "destroy"
        expect(PaperTrail::Version.last.item_id).to eq organization_landing_page.id
      end
    end
  end
end
