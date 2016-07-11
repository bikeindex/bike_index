require 'spec_helper'

describe SessionsController do
  describe 'new' do
    it 'renders and calls store_return_to' do
      expect(controller).to receive(:store_return_to)
      get :new
      expect(response.code).to eq('200')
      expect(response).to render_template('new')
      expect(flash).to_not be_present
      expect(response).to render_with_layout('application_revised')
    end
  end

  describe 'destroy' do
    it 'logs out the current user' do
      user = FactoryGirl.create(:user)
      set_current_user(user)
      get :destroy
      expect(cookies.signed[:auth]).to be_nil
      expect(session[:user_id]).to be_nil
      expect(response).to redirect_to goodbye_url
    end
  end

  describe 'create' do
    describe 'when user is found' do
      before do
        @user = FactoryGirl.create(:user, confirmed: true)
        expect(User).to receive(:fuzzy_email_find).and_return(@user)
      end

      describe 'when authentication works' do
        it 'authenticates' do
          expect(@user).to receive(:authenticate).and_return(true)
          request.env['HTTP_REFERER'] = user_home_url
          post :create, session: { password: 'would be correct' }
          expect(cookies.signed[:auth][1]).to eq(@user.auth_token)
          expect(response).to redirect_to user_home_url
        end

        it 'authenticates and redirects to admin' do
          @user.update_attribute :is_content_admin, true
          expect(@user).to receive(:authenticate).and_return(true)
          request.env['HTTP_REFERER'] = user_home_url
          post :create, session: { password: 'would be correct' }
          expect(cookies.signed[:auth][1]).to eq(@user.auth_token)
          expect(response).to redirect_to admin_news_index_url
        end

        it "redirects to discourse_authentication url if it's a valid oauth url" do
          expect(@user).to receive(:authenticate).and_return(true)
          session[:discourse_redirect] = 'sso=foo&sig=bar'
          post :create, session: { hmmm: 'yeah' }
          expect(User.from_auth(cookies.signed[:auth])).to eq(@user)
          expect(response).to redirect_to discourse_authentication_url
        end

        it "redirects to return_to if it's a valid oauth url" do
          expect(@user).to receive(:authenticate).and_return(true)
          session[:return_to] = oauth_authorization_url(cool_thing: true)
          post :create, session: { stuff: 'lololol' }
          expect(User.from_auth(cookies.signed[:auth])).to eq(@user)
          expect(session[:return_to]).to be_nil
          expect(response).to redirect_to oauth_authorization_url(cool_thing: true)
        end

        it "doesn't redirect and clears the session if not a valid oauth url" do
          expect(@user).to receive(:authenticate).and_return(true)
          session[:return_to] = "http://testhost.com/bad_place?f=#{oauth_authorization_url(cool_thing: true)}"
          post :create, session: { thing: 'asdfasdf' }
          expect(User.from_auth(cookies.signed[:auth])).to eq(@user)
          expect(session[:return_to]).to be_nil
          expect(response).to redirect_to user_home_url
        end
      end

      it 'does not authenticate the user when user authentication fails' do
        expect(@user).to receive(:authenticate).and_return(false)
        post :create, session: { password: 'something incorrect' }
        expect(session[:user_id]).to be_nil
        expect(response).to render_template('new')
        expect(response).to render_with_layout('application_revised')
      end
    end

    it 'does not log in unconfirmed users' do
      user = FactoryGirl.create(:user, confirmed: true)
      expect(User).to receive(:fuzzy_email_find).and_return(user)
      post :create, session: { email: user.email }
      expect(response).to render_template(:new)
      expect(cookies.signed[:auth]).to be_nil
      expect(response).to render_with_layout('application_revised')
    end

    it 'does not log in the user when the user is not found' do
      post :create, session: { email: 'notThere@example.com' }
      expect(cookies.signed[:auth]).to be_nil
      expect(response).to render_template(:new)
      expect(response).to render_with_layout('application_revised')
    end
  end
end
