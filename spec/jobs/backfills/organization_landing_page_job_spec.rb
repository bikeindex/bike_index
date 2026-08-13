require "rails_helper"

RSpec.describe Backfills::OrganizationLandingPageJob, type: :job do
  let(:instance) { described_class.new }
  let(:landing_html) { "<p>Welcome to the landing page</p>" }
  let!(:organization) { FactoryBot.create(:organization, landing_html:) }

  describe "perform" do
    it "copies landing_html, leaves it in place, and doesn't clobber a later edit" do
      expect(LandingPages::ORGANIZATIONS).to_not include(organization.slug)
      expect { instance.perform }.to change(OrganizationLandingPage, :count).by 1
      landing_page = organization.reload.organization_landing_page
      expect(landing_page.body).to eq landing_html
      expect(landing_page.enabled).to be_falsey
      expect(organization.landing_html).to eq landing_html

      landing_page.update!(body: "<p>Edited since the backfill</p>")
      expect { instance.perform }.to change(OrganizationLandingPage, :count).by 0
      expect(landing_page.reload.body).to eq "<p>Edited since the backfill</p>"
      expect { instance.perform }.to_not change { landing_page.reload.updated_at }
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

      it "backfills it, since it can be restored" do
        expect(Organization.find_by(id: organization.id)).to be_blank
        expect { instance.perform }.to change(OrganizationLandingPage, :count).by 1
        expect(OrganizationLandingPage.last.organization_id).to eq organization.id
      end
    end

    context "with an organization in LandingPages::ORGANIZATIONS" do
      include_context :with_paper_trail

      let!(:organization) { FactoryBot.create(:organization, short_name: "Brakebills", landing_html:) }

      it "enables on create, and syncs enabled on a re-run in both directions" do
        expect(LandingPages::ORGANIZATIONS).to include(organization.slug)
        instance.perform
        landing_page = organization.reload.organization_landing_page
        expect(landing_page.enabled).to be_truthy
        # Created enabled, rather than created disabled and immediately flipped
        expect(landing_page.versions.count).to eq 1

        stub_const("LandingPages::ORGANIZATIONS", [])
        instance.perform
        expect(landing_page.reload.enabled).to be_falsey

        stub_const("LandingPages::ORGANIZATIONS", [organization.slug])
        instance.perform
        expect(landing_page.reload.enabled).to be_truthy

        organization.destroy
        instance.perform
        expect(landing_page.reload.enabled).to be_falsey
      end
    end
  end
end
