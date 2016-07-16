require 'spec_helper'

describe Admin::OrganizationsController, type: :controller do
  let(:organization) { FactoryGirl.create(:organization) }
  let(:user) { FactoryGirl.create(:admin) }
  before do
    set_current_user(user)
  end

  describe 'index' do
    it 'renders' do
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe 'edit' do
    context 'standard' do
      it 'renders' do
        get :edit, id: organization.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end
    context 'landing page' do
      it 'renders' do
        get :edit, id: organization.to_param, landing_page: 1
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit_landing_page)
      end
    end
  end

  describe 'organization update' do
    it 'updates the organization' do
      org_attrs = { name: 'new name thing stuff', landing_html: '<p>html</p>' }
      put :update, id: organization.to_param, organization: org_attrs
      organization.reload
      expect(organization.name).to eq org_attrs[:name]
      expect(organization.landing_html).to eq org_attrs[:landing_html]
    end
  end
end
