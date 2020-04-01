require "rails_helper"

# Need these as controller specs, because we're testing setting session
RSpec.describe Organized::ManageController, type: :controller do
  context "logged_in_as_organization_admin" do
    include_context :logged_in_as_organization_admin
    describe "index" do
      it "renders, sets active organization" do
        session[:passive_organization_id] = "XXXYYY"
        get :index, params: { organization_id: organization.to_param }
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:current_organization)).to eq organization
        expect(assigns(:passive_organization)).to eq organization
        expect(session[:passive_organization_id]).to eq organization.id
      end
    end

    describe "landing" do
      it "renders" do
        session[:passive_organization_id] = "XXXYYY"
        get :landing, params: { organization_id: organization.to_param }
        expect(response.status).to eq(200)
        expect(assigns(:current_organization)).to eq organization
        expect(assigns(:passive_organization)).to eq organization
        expect(session[:passive_organization_id]).to eq organization.id
      end
    end
  end
end
