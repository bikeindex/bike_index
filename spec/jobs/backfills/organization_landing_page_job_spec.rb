require "rails_helper"

RSpec.describe Backfills::OrganizationLandingPageJob, type: :job do
  let(:instance) { described_class.new }
  let(:landing_html) { "<p>Welcome to the landing page</p>" }
  let!(:organization) { FactoryBot.create(:organization, landing_html:) }

  describe "perform" do
    it "copies landing_html and leaves it in place" do
      expect(LandingPages::ORGANIZATIONS).to_not include(organization.slug)
      expect { instance.perform }.to change(OrganizationLandingPage, :count).by 1
      landing_page = organization.reload.organization_landing_page
      expect(landing_page.body).to eq landing_html
      expect(landing_page.organization_slug).to eq organization.slug
      expect(landing_page.enabled).to be_falsey
      expect(organization.landing_html).to eq landing_html
    end

    context "with an organization in LandingPages::ORGANIZATIONS" do
      let!(:organization) { FactoryBot.create(:organization, short_name: "Brakebills", landing_html:) }

      it "enables it, matching what renders today" do
        expect(LandingPages::ORGANIZATIONS).to include(organization.slug)
        instance.perform
        expect(organization.reload.organization_landing_page.enabled).to be_truthy
      end
    end

    it "is idempotent" do
      instance.perform
      organization.organization_landing_page.update!(body: "<p>Edited since the backfill</p>")

      expect { instance.perform }.to change(OrganizationLandingPage, :count).by 0
      expect(organization.reload.organization_landing_page.body).to eq "<p>Edited since the backfill</p>"
    end

    context "with a blank landing_html" do
      let!(:blank) { FactoryBot.create(:organization, landing_html: "") }
      let!(:nil_landing_html) { FactoryBot.create(:organization) }

      it "skips the organization" do
        expect { instance.perform }.to change(OrganizationLandingPage, :count).by 1
        expect(blank.reload.organization_landing_page).to be_blank
        expect(nil_landing_html.reload.organization_landing_page).to be_blank
      end
    end

    context "with a deleted organization" do
      before { organization.destroy }

      it "backfills it without a slug, since it can be restored" do
        expect(Organization.find_by(id: organization.id)).to be_blank
        expect { instance.perform }.to change(OrganizationLandingPage, :count).by 1
        expect(OrganizationLandingPage.last.organization_id).to eq organization.id
        expect(OrganizationLandingPage.last.organization_slug).to be_nil
      end
    end
  end
end
