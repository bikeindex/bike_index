require "rails_helper"

RSpec.describe OrganizationLandingPage, type: :model do
  let(:organization_landing_page) { FactoryBot.create(:organization_landing_page) }

  describe "factory" do
    it "is valid, and permits one landing page per organization" do
      expect(organization_landing_page.body).to be_present
      expect(organization_landing_page.enabled).to be_falsey
      expect(organization_landing_page.organization.organization_landing_page).to eq organization_landing_page

      duplicate = described_class.new(organization_id: organization_landing_page.organization_id)
      expect(duplicate).to_not be_valid
      expect(duplicate.errors.full_messages.join).to match(/already been taken/i)
    end

    context "with a blank body" do
      let(:organization_landing_page) { FactoryBot.create(:organization_landing_page, body: "  ") }

      it "stores nil" do
        expect(organization_landing_page.body).to be_nil
      end
    end
  end

  describe "touching the organization" do
    let(:organization) { FactoryBot.create(:organization) }
    let!(:organization_landing_page) { FactoryBot.create(:organization_landing_page, organization:) }

    it "touches on save, so the fragment keyed on the organization busts" do
      organization.update_column(:updated_at, Time.current - 1.hour)

      expect { organization_landing_page.update!(body: "<p>Edited</p>") }
        .to change { organization.reload.updated_at }
    end
  end

  describe "enabled_mismatch_error" do
    let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
    let(:organization_landing_page) { FactoryBot.create(:organization_landing_page, organization:) }

    it "reports a routed organization whose page is disabled" do
      expect(LandingPages::ORGANIZATIONS).to include(organization.slug)
      expect(organization_landing_page.env_enabled?).to be_truthy
      # The factory default, so a routed organization starts out disagreeing
      expect(organization_landing_page.enabled).to be_falsey
      expect(organization_landing_page.enabled_mismatch_error)
        .to match(/enabled is false.*includes "brakebills"/)

      organization_landing_page.update!(enabled: true)
      expect(organization_landing_page.enabled_mismatch_error).to be_nil
    end

    context "with an organization that isn't routed" do
      let(:organization) { FactoryBot.create(:organization) }

      it "reports only when the page is enabled" do
        expect(organization_landing_page.env_enabled?).to be_falsey
        expect(organization_landing_page.enabled_mismatch_error).to be_nil

        organization_landing_page.update!(enabled: true)
        expect(organization_landing_page.enabled_mismatch_error)
          .to match(/enabled is true.*does not include "#{organization.slug}"/)
      end
    end
  end

  describe "versioning" do
    include_context :with_paper_trail

    let(:organization_landing_page) { FactoryBot.create(:organization_landing_page, body: "<p>Original</p>") }

    it "versions body and enabled, and snapshots the whole record on destroy" do
      expect(organization_landing_page.versions.count).to eq 1
      version = organization_landing_page.versions.last
      expect(version.event).to eq "create"
      expect(version.object_changes)
        .to eq({body: [nil, "<p>Original</p>"], organization_id: [nil, organization_landing_page.organization_id]}.as_json)

      organization_landing_page.update!(body: "<p>Updated</p>")
      expect(organization_landing_page.versions.count).to eq 2
      version = organization_landing_page.versions.last
      expect(version.event).to eq "update"
      expect(version.object_changes).to eq({body: ["<p>Original</p>", "<p>Updated</p>"]}.as_json)
      expect(version.reify.body).to eq "<p>Original</p>"

      organization_landing_page.update!(enabled: true)
      expect(organization_landing_page.versions.count).to eq 3
      expect(organization_landing_page.versions.last.object_changes).to eq({enabled: [false, true]}.as_json)

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
