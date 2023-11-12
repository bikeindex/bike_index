require "rails_helper"

RSpec.describe Organized::ModelAuditsController, type: :request do
  let(:root_path) { "/o/#{current_organization.to_param}/bikes" }
  let(:base_url) { "/o/#{current_organization.to_param}/model_audits" }
  let!(:organization_model_audit) { FactoryBot.create(:organization_model_audit, organization: current_organization) }

  include_context :request_spec_logged_in_as_organization_admin

  context "organization without model_audits" do
    context "logged in as organization admin" do
      describe "index" do
        it "redirects" do
          get base_url
          expect(response).to redirect_to organization_root_path(organization_id: current_organization.to_param)
          expect(flash[:error]).to be_present
        end
      end
    end

    context "logged in as super admin" do
      let(:current_user) { FactoryBot.create(:admin) }
      describe "index" do
        it "renders" do
          expect(current_user.member_of?(current_organization, no_superuser_override: true)).to be_falsey
          get base_url
          expect(response).to render_template(:index)
          expect(assigns(:current_organization)&.id).to eq current_organization.id
        end
      end
    end
  end

  context "organization with model_audits" do
    let!(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["model_audits"]) }
    let(:current_user) { FactoryBot.create(:organization_member, organization: current_organization) }

    describe "index" do
      it "renders" do
        expect(current_user.memberships.first.role).to eq "member"
        current_organization.reload
        get base_url
        expect(response.code).to eq("200")
        expect(response).to render_template(:index)
        expect(assigns(:current_organization)&.id).to eq current_organization.id
        expect(assigns(:organization_model_audits).pluck(:id)).to eq([])
        # But if passed search_zero, it includes the model_audit
        get base_url, params: {search_zero: true}
        expect(assigns(:organization_model_audits).pluck(:id)).to eq([organization_model_audit.id])
      end
    end

    describe "show" do
      let(:model_audit) { FactoryBot.create(:model_audit) }
      let!(:model_attestation) { FactoryBot.create(:model_attestation, organization: current_organization, model_audit: model_audit) }
      it "renders" do
        get "#{base_url}/#{model_audit.id}"
        expect(response.code).to eq("200")
        expect(response).to render_template(:show)
        expect(assigns(:model_attestations).pluck(:id)).to eq([model_attestation.id])
        # It renders with a model attestation too
      end
    end

    describe "update create" do
      it "creates a model_attestation" do
        expect(organization_model_audit.model_attestations.count).to eq 0
        expect(organization_model_audit.certification_status).to be_nil
        post base_url, params: {
          model_audit_id: organization_model_audit.model_audit_id,
          url: " ffff.com/sss ",
          info: "Some cool info",
          kind: "certified_by_trusted_org"
        }
        expect(flash[:success]).to be_present
        expect(organization_model_audit.model_attestations.count).to eq 1
        model_attestation = organization_model_audit.model_attestations.first
        expect(model_attestation.user_id).to eq current_user.id
        expect(model_attestation.organization_id).to eq current_organization.id
        expect(model_attestation.url).to eq "http://ffff.com/sss"
        expect(model_attestation.info).to eq "Some cool info"
        expect(model_attestation.kind).to eq "certified_by_trusted_org"
        # Needs to update inline or else the page doesn't show what you just did
        expect(organization_model_audit.reload.certification_status).to eq "certified_by_your_org"
      end
    end
  end
end
