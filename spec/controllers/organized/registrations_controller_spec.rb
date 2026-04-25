require "rails_helper"

# Controller specs only for tests that need session access
# All other tests belong in spec/requests/organized/registrations_request_spec.rb
RSpec.describe Organized::RegistrationsController, type: :controller do
  context "not organization member" do
    include_context :logged_in_as_user
    let!(:organization) { FactoryBot.create(:organization) }

    it "redirects the user, reassigns passive_organization_id" do
      session[:passive_organization_id] = "0" # Because, who knows! Maybe they don't have org access at some point.
      get :index, params: {organization_id: organization.to_param}
      expect(response.location).to eq my_account_url
      expect(flash[:error]).to be_present
      expect(session[:passive_organization_id]).to eq "0" # sets it to zero so we don't look it up again
    end

    context "admin user" do
      let(:user) { FactoryBot.create(:superuser) }
      it "renders, doesn't reassign passive_organization_id" do
        session[:passive_organization_id] = organization.to_param # Admin, so user has access
        get :index, params: {organization_id: organization.to_param}
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:current_organization)).to eq organization
        expect(assigns(:page_id)).to eq "organized_registrations_index"
        expect(assigns(:passive_organization)).to eq organization
        expect(session[:passive_organization_id]).to eq organization.id
      end
    end
  end
end
