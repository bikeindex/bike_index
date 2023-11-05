require "rails_helper"

RSpec.describe Organized::ModelAuditsController, type: :request do
  let(:root_path) { "/o/#{current_organization.to_param}/bikes" }
  let(:base_url) { "/o/#{current_organization.to_param}/model_audits" }

  include_context :request_spec_logged_in_as_organization_admin

  context "organization without model_audits" do
    context "logged in as organization admin" do
      describe "index" do
        it "redirects" do
          get base_url
          expect(response).to redirect_to root_path
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
    let(:enabled_feature_slugs) { ["model_audits"] }
    let!(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: enabled_feature_slugs) }
    let(:current_user) { FactoryBot.create(:organization_member, organization: current_organization) }

    # describe "index" do
    #   it "renders" do
    #     expect(current_user.memberships.first.role).to eq "member"
    #     expect(export).to be_present # So that we're actually rendering an export
    #     current_organization.reload
    #     expect(current_organization.enabled?("csv_exports")).to be_truthy
    #     get base_url
    #     expect(response.code).to eq("200")
    #     expect(response).to render_template(:index)
    #     expect(assigns(:current_organization)).to eq current_organization
    #     expect(assigns(:exports).pluck(:id)).to eq([export.id])
    #   end
    # end
  end
end
