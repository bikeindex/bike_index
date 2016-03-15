require 'spec_helper'

describe SessionsController do

  describe :new do 
    it "sets the user session to blank" do 
      user = User.new
      user.stub(:id).and_return(69)
      set_current_user(user)
      get :destroy
      session[:user_id].should be_nil
    end
    it 'calls set_return_to' do
      expect(controller).to receive(:set_return_to)
      get :new
    end
  end

  describe :destroy do 
    before do 
      get :new
    end
    it { should respond_with(:success) }
    it { should render_template(:new) }
    it { should_not set_the_flash }
  end

  describe :create do
    describe "when user is found" do
      before :each do
        @user = FactoryGirl.create(:user, confirmed: true)
        User.should_receive(:fuzzy_email_find).and_return(@user)
      end

      describe "when authentication works" do
        it "authenticates" do
          @user.should_receive(:authenticate).and_return(true)
          request.env["HTTP_REFERER"] = user_home_url
          post :create, session: {}
          cookies.signed[:auth][1].should eq(@user.auth_token)
          response.should redirect_to user_home_url
        end

        it "authenticates and redirects to admin" do
          @user.update_attribute :is_content_admin, true
          @user.should_receive(:authenticate).and_return(true)
          request.env["HTTP_REFERER"] = user_home_url
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

      it "does not authenticate the user when user authentication fails" do
        @user.should_receive(:authenticate).and_return(false)
        post :create, session: {}
        session[:user_id].should be_nil
        response.should render_template("new")
      end
    end

    it "does not log in unconfirmed users" do
      @user = FactoryGirl.create(:user, confirmed: true)
      User.should_receive(:fuzzy_email_find).and_return(@user)
      post :create, session: {}
      response.should render_template(:new)
      cookies.signed[:auth].should be_nil
    end

    it "does not log in the user when the user is not found" do
      post :create, session: { email: "notThere@example.com" }
      cookies.signed[:auth].should be_nil
      response.should render_template(:new)
    end
  end


  describe :logout do
    it "logs out the current user" do
      user = FactoryGirl.create(:user)
      set_current_user(user)
      get :destroy
      cookies.signed[:auth].should be_nil
      response.should redirect_to goodbye_url
    end
  end
end
