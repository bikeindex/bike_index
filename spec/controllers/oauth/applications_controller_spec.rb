require 'spec_helper'

describe Oauth::ApplicationsController do
  describe 'index' do
    context 'current user present' do
      it 'renders' do
        user = FactoryGirl.create(:user)
        set_current_user(user)
        get :index
        expect(response.status).to eq 200
        expect(response).to render_template(:index)
      end
    end
    context 'no current user present' do
      it 'redirects' do
        get :index
        expect(response).to redirect_to new_session_url
        expect(flash[:error]).to be_present
      end
    end
  end

  describe 'create' do
    it 'creates an application and adds the v2 accessor to it' do
      create_v2_access_id
      user = FactoryGirl.create(:user)
      set_current_user(user)
      app_attrs = {
        name: 'Some app',
        redirect_uri: 'urn:ietf:wg:oauth:2.0:oob'
      }
      post :create, doorkeeper_application: app_attrs
      app = user.oauth_applications.first
      expect(app.name).to eq(app_attrs[:name])
      expect(app.access_tokens.count).to eq(1)
      v2_accessor = app.access_tokens.last
      expect(v2_accessor.resource_owner_id).to eq(ENV['V2_ACCESSOR_ID'].to_i)
      expect(v2_accessor.scopes).to eq(['write_bikes'])
    end
  end

  describe 'edit' do
    it 'renders if owned by user' do
      create_doorkeeper
      set_current_user(@user)
      get :edit, id: @application.id
      expect(response.code).to eq('200')
      expect(flash).not_to be_present
    end

    it 'renders if superuser' do
      create_doorkeeper
      admin = FactoryGirl.create(:admin)
      set_current_user(admin)
      get :edit, id: @application.id
      expect(response.code).to eq('200')
      expect(flash).not_to be_present
    end

    it 'redirects if no user present' do
      create_doorkeeper
      get :edit, id: @application.id
      expect(response).to redirect_to new_session_url
      expect(flash).to be_present
    end

    it 'redirects if not owned by user' do
      create_doorkeeper
      visitor = FactoryGirl.create(:user)
      set_current_user(visitor)
      get :edit, id: @application.id
      expect(response).to redirect_to oauth_applications_url
      expect(flash).to be_present
    end
  end

  describe 'update' do
    it 'renders if owned by user' do
      create_doorkeeper
      set_current_user(@user)
      put :update, id: @application.id, doorkeeper_application: { name: 'new thing' }
      @application.reload
      expect(@application.name).to eq('new thing')
    end

    it "doesn't update if not users" do
      create_doorkeeper
      name = @application.name
      user = FactoryGirl.create(:user)
      set_current_user(user)
      put :update, id: @application.id, doorkeeper_application: { name: 'new thing' }
      @application.reload
      expect(@application.name).to eq(name)
      expect(response).to redirect_to oauth_applications_url
    end
  end
end
