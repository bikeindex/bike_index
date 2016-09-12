require 'spec_helper'

describe IntegrationsController do
  describe 'create' do
    describe 'when there is no user' do
      it 'creates an integration' do
        request.env['omniauth.auth'] = OmniAuth.config.mock_auth[:facebook]
        expect do
          post :create
        end.to change(Integration, :count).by(1)
        expect(response.code).to eq('302')
        user = User.last
        expect(User.from_auth(cookies.signed[:auth])).to eq(user)
      end
    end

    describe 'when there is a user' do
      let(:user) { FactoryGirl.create(:user) }
      before :each do
        set_current_user(user)
        request.env['omniauth.auth'] = OmniAuth.config.mock_auth[:facebook]
      end

      it 'creates a new integration given a refresh token and access token' do
        expect do
          get :create, access_token: '123456', expires_in: '3920',
                       token_type: 'Bearer', refresh_token: '1/xEoDL4iW3cxlI7yDbSRFYNG01kVKM2C-259HOF2aQbI'
          expect(response).to redirect_to(user_home_url)
        end.to change(Integration, :count).by 1
      end

      it 'uses the redirect' do
        get :create, access_token: '123456', expires_in: '3920',
                     token_type: 'Bearer', return_to: 'https://facebook.com/bikeindex',
                     refresh_token: '1/xEoDL4iW3cxlI7yDbSRFYNG01kVKM2C-259HOF2aQbI'
        expect(response).to redirect_to 'https://facebook.com/bikeindex'
      end
    end
  end

  describe 'failure' do
    it 'renders sessions new with a flash' do
      get :integrations_controller_creation_error, message: 'csrf_detected', strategy: 'facebook'
      expect(flash[:error]).to match('email us at contact@bikeindex.org')
      expect(response).to redirect_to new_session_path
    end
  end
end
