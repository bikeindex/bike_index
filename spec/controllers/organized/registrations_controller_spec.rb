require "rails_helper"

# Need controller specs to test setting session
#
# PUT ALL TESTS IN Request spec !
#
RSpec.describe Organized::RegistrationsController, type: :controller do
  context "given an authenticated ambassador" do
    include_context :logged_in_as_ambassador
    it "redirects to the organization root path" do
      expect(get(:index, params: {organization_id: organization})).to redirect_to(organization_root_path)
    end
    describe "multi_serial_search" do
      it "renders" do
        get :multi_serial_search, params: {organization_id: organization.to_param}
        expect(response.status).to eq(200)
        expect(response).to render_template :multi_serial_search
      end
    end
  end

  let(:non_organization_bike) { FactoryBot.create(:bike) }
  before do
    expect(non_organization_bike).to be_present
  end

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

  context "logged_in_as_organization_admin" do
    include_context :logged_in_as_organization_admin
    describe "index" do
      it "renders" do
        get :index, params: {organization_id: organization.to_param}
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:current_organization)).to eq organization
        expect(assigns(:page_id)).to eq "organized_registrations_index"
      end
    end
  end
end
