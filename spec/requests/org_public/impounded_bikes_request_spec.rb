require "rails_helper"

RSpec.describe OrgPublic::ImpoundedBikesController, type: :request do
  let(:base_url) { "/#{current_organization.to_param}/impounded_bikes" }
  let(:current_organization) { FactoryBot.create(:organization) }

  it "redirects" do
    expect {
      get "/some-unknown-organization/impounded_bikes"
    }.to raise_error(ActiveRecord::RecordNotFound)
  end

  context "organization not enabled" do
    include_context :request_spec_logged_in_as_organization_member
    it "redirects" do
      expect(current_organization.enabled?("impound_bikes")).to be_falsey
      expect(current_organization.public_impound_bikes).to be_falsey
      get base_url
      expect(flash[:error]).to be_present
      expect(response).to redirect_to root_url
    end
  end

  context "impound_bikes, but not public_impound_bikes_page" do
    let(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "impound_bikes") }
    it "redirects" do
      expect(current_organization.public_impound_bikes).to be_falsey
      get base_url
      expect(flash[:error]).to be_present
      expect(response).to redirect_to root_url
    end
    context "logged in as organization member" do
      include_context :request_spec_logged_in_as_organization_member
      it "renders" do
        expect(current_organization.public_impound_bikes).to be_truthy
        get base_url
        expect(flash[:success]).to be_present
        expect(response.status).to eq(200)
        expect(response).to render_template :index
      end
    end
  end

  context "organization has impound_bikes" do
    let(:current_organization) { FactoryBot.create(:organization_with_organization_features, public_impound_bikes: true, enabled_feature_slugs: "impound_bikes") }

    it "renders" do
      expect(current_organization.public_impound_bikes).to be_truthy
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template :index
    end
  end
end
