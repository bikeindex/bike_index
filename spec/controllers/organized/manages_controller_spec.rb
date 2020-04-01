require "rails_helper"

# Need controller specs to test setting session
#
# PUT ALL TESTS IN Request spec !
#
RSpec.describe Organized::ManagesController, type: :controller do
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
