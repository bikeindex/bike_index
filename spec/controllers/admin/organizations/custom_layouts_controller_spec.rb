require 'spec_helper'

describe Admin::Organizations::CustomLayoutsController, type: :controller do
  let(:organization) { FactoryGirl.create(:organization) }
  context 'super admin' do
    include_context :logged_in_as_super_admin

    describe 'index' do
      it 'redirects' do
        get :index, organization_id: organization.to_param
        expect(response).to redirect_to(admin_organization_url(organization))
        expect(flash).to be_present
      end
    end
  end

  context 'super admin and developer' do
    let(:user) { FactoryGirl.create(:admin, developer: true) }
    before do
      set_current_user(user)
    end

    describe 'index' do
      it 'renders' do
        get :index, organization_id: organization.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end

    describe 'edit' do
      context 'landing_page' do
        it 'renders' do
          get :edit, organization_id: organization.to_param, id: 'landing_page'
          expect(response.status).to eq(200)
          expect(response).to render_template(:edit_landing_page)
        end
      end
      context 'mail_snippets' do
        it 'renders' do
          get :edit, organization_id: organization.to_param, id: 'mail_snippets'
          expect(response.status).to eq(200)
          expect(response).to render_template(:edit_mail_snippets)
        end
      end
    end

    describe 'organization update' do
      context 'landing_page' do
        let(:update_attributes) { { landing_html: '<p>html for the landing page</p>' } }
        it 'updates and redirects to the landing_page edit' do
          put :update, organization_id: organization.to_param,
              organization: update_attributes, id: 'landing_page'
          target = edit_admin_organization_custom_layout_path(organization_id: organization.to_param, id: 'landing_page')
          expect(response).to redirect_to target
          organization.reload
          expect(organization.landing_html).to eq update_attributes[:landing_html]
        end
      end
    end
  end
end
