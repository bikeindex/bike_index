require "rails_helper"

# Need controller specs to test setting session
#
# PUT ALL TESTS IN Request spec !
#
RSpec.describe Organized::ManagesController, type: :controller do
  context "not signed in" do
    let!(:organization) { FactoryBot.create(:organization) }
    it "redirects" do
      get :show, params: { organization_id: organization.id }
      expect(session[:return_to]).to eq organization_manage_path(organization_id: organization.id)
      expect(session[:passive_organization_id]).to eq organization.id
      expect(flash[:notice]).to be_present
      expect(response).to redirect_to(new_session_path)
    end
    context "organization has passwordless_users" do
      let!(:organization) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: ["passwordless_users"]) }
      it "redirects to magic link" do
        get :show, params: { organization_id: organization.id }
        expect(session[:return_to]).to eq organization_manage_path(organization_id: organization.id)
        expect(session[:passive_organization_id]).to eq organization.id
        expect(flash[:notice]).to be_present
        expect(response).to redirect_to(magic_link_session_path)
      end
    end
  end

  context "logged_in_as_organization_admin" do
    include_context :logged_in_as_organization_admin
    describe "show" do
      it "renders, sets active organization" do
        session[:passive_organization_id] = "XXXYYY"
        get :show, params: { organization_id: organization.to_param }
        expect(response.status).to eq(200)
        expect(response).to render_template :show
        expect(assigns(:current_organization)).to eq organization
        expect(assigns(:passive_organization)).to eq organization
        expect(session[:passive_organization_id]).to eq organization.id
      end
    end
  end
end
