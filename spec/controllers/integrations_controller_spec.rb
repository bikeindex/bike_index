require 'spec_helper'

describe IntegrationsController do
  describe :create do
    describe 'when there is no user' do
      it 'creates an integration' do
        request.env['omniauth.auth'] = OmniAuth.config.mock_auth[:facebook]
        expect do
          post :create
        end.to change(Integration, :count).by(1)
        response.code.should eq('302')
        user = User.last
        User.from_auth(cookies.signed[:auth]).should eq(user)
      end
    end

    describe 'when there is a user' do
      before :each do
        @user = FactoryGirl.create(:user)
        set_current_user(@user)
        request.env['omniauth.auth'] = OmniAuth.config.mock_auth[:facebook]
      end

      it 'creates a new integration given a refresh token and access token' do
        expect do
          get :create, access_token: '123456', expires_in: '3920', token_type: 'Bearer', refresh_token: '1/xEoDL4iW3cxlI7yDbSRFYNG01kVKM2C-259HOF2aQbI'
          response.should redirect_to(user_home_url)
        end.to change(Integration, :count).by 1
      end
    end
  end
end
