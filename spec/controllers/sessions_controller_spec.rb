require 'spec_helper'

describe SessionsController do
  describe :new do
    context 'legacy' do
      it 'renders and calls set_return_to' do
        expect(controller).to receive(:set_return_to)
        get :new
        expect(response.code).to eq('200')
        expect(response).to render_template('new')
        expect(flash).to_not be_present
        expect(response).to render_with_layout('application')
      end
    end
    context 'revised' do
      it 'renders and calls set_return_to' do
        allow(controller).to receive(:revised_layout_enabled?) { true }
        expect(controller).to receive(:set_return_to)
        get :new
        expect(response.code).to eq('200')
        expect(response).to render_template('new_revised')
        expect(flash).to_not be_present
        expect(response).to render_with_layout('application_revised')
      end
    end
  end

  describe :destroy do
    it 'logs out the current user' do
      user = FactoryGirl.create(:user)
      set_current_user(user)
      get :destroy
      cookies.signed[:auth].should be_nil
      session[:user_id].should be_nil
      response.should redirect_to goodbye_url
    end
  end

  describe :create do
    describe 'when user is found' do
      before do
        @user = FactoryGirl.create(:user, confirmed: true)
        User.should_receive(:fuzzy_email_find).and_return(@user)
      end

      describe 'when authentication works' do
        it 'authenticates' do
          @user.should_receive(:authenticate).and_return(true)
          request.env['HTTP_REFERER'] = user_home_url
          post :create, session: {}
          cookies.signed[:auth][1].should eq(@user.auth_token)
          response.should redirect_to user_home_url
        end

        it 'authenticates and redirects to admin' do
          @user.update_attribute :is_content_admin, true
          @user.should_receive(:authenticate).and_return(true)
          request.env['HTTP_REFERER'] = user_home_url
          post :create, session: {}
          cookies.signed[:auth][1].should eq(@user.auth_token)
          response.should redirect_to admin_news_index_url
        end

        it "redirects to discourse_authentication url if it's a valid oauth url" do
          @user.should_receive(:authenticate).and_return(true)
          session[:discourse_redirect] = 'sso=foo&sig=bar'
          post :create, session: session
          User.from_auth(cookies.signed[:auth]).should eq(@user)
          response.should redirect_to discourse_authentication_url
        end

        it "redirects to return_to if it's a valid oauth url" do
          @user.should_receive(:authenticate).and_return(true)
          session[:return_to] = oauth_authorization_url(cool_thing: true)
          post :create, session: session
          User.from_auth(cookies.signed[:auth]).should eq(@user)
          session[:return_to].should be_nil
          response.should redirect_to oauth_authorization_url(cool_thing: true)
        end

        it "doesn't redirect and clears the session if not a valid oauth url" do
          @user.should_receive(:authenticate).and_return(true)
          session[:return_to] = "http://testhost.com/bad_place?f=#{oauth_authorization_url(cool_thing: true)}"
          post :create, session: session
          User.from_auth(cookies.signed[:auth]).should eq(@user)
          session[:return_to].should be_nil
          response.should redirect_to user_home_url
        end
      end

      it 'does not authenticate the user when user authentication fails' do
        @user.should_receive(:authenticate).and_return(false)
        post :create, session: {}
        session[:user_id].should be_nil
        response.should render_template('new')
        expect(response).to render_with_layout('application')
      end
    end

    it 'does not log in unconfirmed users' do
      user = FactoryGirl.create(:user, confirmed: true)
      User.should_receive(:fuzzy_email_find).and_return(user)
      post :create, session: {}
      response.should render_template(:new)
      cookies.signed[:auth].should be_nil
      expect(response).to render_with_layout('application')
    end

    it 'does not log in the user when the user is not found' do
      post :create, session: { email: 'notThere@example.com' }
      cookies.signed[:auth].should be_nil
      response.should render_template(:new)
      expect(response).to render_with_layout('application')
    end
  end
end
