require "rails_helper"

RSpec.describe Backfills::OrganizationLandingPageJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
    let!(:landing_page) { FactoryBot.create(:organization_landing_page, organization:) }

    it "syncs enabled with LandingPages::ORGANIZATIONS in both directions" do
      expect(LandingPages::ORGANIZATIONS).to include(organization.slug)
      expect(landing_page.enabled).to be_falsey
      instance.perform
      expect(landing_page.reload.enabled).to be_truthy

      stub_const("LandingPages::ORGANIZATIONS", [])
      instance.perform
      expect(landing_page.reload.enabled).to be_falsey

      expect { instance.perform }.to_not change { landing_page.reload.updated_at }
    end

    context "with a deleted organization" do
      it "disables the page" do
        instance.perform
        expect(landing_page.reload.enabled).to be_truthy

        organization.destroy
        instance.perform
        expect(landing_page.reload.enabled).to be_falsey
      end
    end

    context "with an organization not in LandingPages::ORGANIZATIONS" do
      let(:organization) { FactoryBot.create(:organization) }

      it "leaves the page disabled" do
        expect(LandingPages::ORGANIZATIONS).to_not include(organization.slug)
        expect { instance.perform }.to_not change { landing_page.reload.updated_at }
        expect(landing_page.enabled).to be_falsey
      end
    end
  end
end
