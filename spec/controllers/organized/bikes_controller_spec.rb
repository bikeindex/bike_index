require 'spec_helper'

describe Organized::BikesController, type: :controller do
  context 'logged_in_as_organization_admin' do
    include_context :logged_in_as_organization_admin
    describe 'index' do
      it 'renders' do
        get :index, organization_id: organization.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(response).to render_with_layout('application_revised')
        expect(assigns(:current_organization)).to eq organization
      end
    end

    describe 'new' do
      it 'renders' do
        get :new, organization_id: organization.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template :new
        expect(response).to render_with_layout('application_revised')
        expect(assigns(:current_organization)).to eq organization
      end
    end
  end

  context 'logged_in_as_organization_member' do
    include_context :logged_in_as_organization_member
    describe 'index' do
      it 'renders' do
        get :index, organization_id: organization.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(response).to render_with_layout('application_revised')
        expect(assigns(:current_organization)).to eq organization
      end
    end

    describe 'new' do
      it 'renders' do
        get :new, organization_id: organization.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template :new
        expect(response).to render_with_layout('application_revised')
        expect(assigns(:current_organization)).to eq organization
      end
    end
  end
end
