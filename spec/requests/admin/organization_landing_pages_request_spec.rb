# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::OrganizationLandingPagesController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let!(:organization_landing_page) { FactoryBot.create(:organization_landing_page) }

  base_url = "/admin/organization_landing_pages"

  describe "#index" do
    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:collection).pluck(:id)).to eq([organization_landing_page.id])
    end

    context "with an organization_id" do
      let!(:other_landing_page) { FactoryBot.create(:organization_landing_page) }

      it "renders only that organization's page" do
        get base_url, params: {organization_id: other_landing_page.organization.to_param}
        expect(response.status).to eq(200)
        expect(assigns(:collection).pluck(:id)).to eq([other_landing_page.id])
      end
    end

    context "with enabled disagreeing with ORGANIZATIONS_WITH_LANDING_PAGES" do
      let!(:organization_landing_page) { FactoryBot.create(:organization_landing_page, enabled: true) }

      it "renders the mismatch" do
        expect(organization_landing_page.env_enabled?).to be_falsey
        get base_url
        expect(response.status).to eq(200)
        expect(response.body).to match("Mismatch")
      end
    end
  end
end
