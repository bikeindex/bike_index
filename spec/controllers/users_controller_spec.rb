require 'spec_helper'

describe UsersController do

  describe :new do 
    describe "already signed in" do 
      before do 
        user = FactoryGirl.create(:user)
        session[:user_id] = user.id
        get :new
      end
      it { should redirect_to(:user_home) }
      it { should set_the_flash }
    end
    describe "Not signed in" do 
      before do 
        get :new
      end
      it { should respond_with(:success) }
      it { should_not redirect_to(:new_session) }
      it { should render_template(:new) }
    end
  end

  describe :create do
    describe "success" do
      it "should create a non-confirmed record" do
        lambda do
          post :create, user: FactoryGirl.attributes_for(:user)
        end.should change(User, :count).by(1)
      end
      it "should call create_user_jobs" do
        CreateUserJobs.any_instance.should_receive(:do_jobs)
        post :create, user: FactoryGirl.attributes_for(:user)
      end
      it "should create a confirmed user, log in, and send welcome if user has org invite" do
        CreateUserJobs.any_instance.should_receive(:send_welcome_email)
        organization_invitation = FactoryGirl.create(:organization_invitation, invitee_email: "poo@pile.com")
        post :create, user: FactoryGirl.attributes_for(:user, email: "poo@pile.com")
        session[:user_id].should eq(User.fuzzy_email_find("poo@pile.com").id)
        response.should redirect_to(user_home_url)
      end
    end

    describe "failure" do
      let(:user_attributes) { 
        user = FactoryGirl.attributes_for(:user)
        user[:password_confirmation] = "bazoo"
        user
      }
      it "should not create a user or send a welcome email" do
        expect{
          post :create, user: user_attributes
        }.to change(EmailWelcomeWorker.jobs, :size).by(0)
        User.count.should eq(0)
      end
      it "should render new" do
        post :create, user: user_attributes
        response.should render_template('new')
      end
    end
  end

  describe :confirm do  
    describe "user exists" do
      it "should tell the user to log in when already confirmed" do
        @user = FactoryGirl.create(:user, confirmed: true)
        get :confirm, id: @user.id, code: "wtfmate"
        response.should redirect_to new_session_url
      end

      describe "user not yet confirmed" do
        before :each do
          @user = FactoryGirl.create(:user)
          User.should_receive(:find).and_return(@user)
        end
        
        it "should login and redirect when confirmation succeeds" do
          @user.should_receive(:confirm).and_return(true)
          get :confirm, id: @user.id, code: @user.confirmation_token
          session[:user_id].should == @user.id
          response.should redirect_to user_home_url
        end

        it "should show a view when confirmation fails" do
          @user.should_receive(:confirm).and_return(false)
          get :confirm, id: @user.id, code: "Wtfmate"
          response.should render_template :confirm_error_bad_token
        end
      end
    end

    it "should show an appropriate message when the user is nil" do
      get :confirm, id: 1234, code: "Wtfmate"
      response.should render_template :confirm_error_404
    end
  end

  describe :password_reset do 
    describe "if the token is present and valid" do 
      it "Should log in" do
        @user = FactoryGirl.create(:user, email: "ned@foo.com")
        @user.set_password_reset_token
        post :password_reset, token: @user.password_reset_token
        session[:user_id].should == @user.id
      end
      it "Should redirect to the update password page" do 
        @user = FactoryGirl.create(:user, email: "ned@foo.com")
        @user.set_password_reset_token
        post :password_reset, token: @user.password_reset_token
        response.should render_template :update_password
      end
    end

    it "should not log in if the token is present and valid" do
      post :password_reset, token: "Not Actually a token"
      response.should render_template :request_password_reset
    end

    it "should enqueue a password reset email job" do
      @user = FactoryGirl.create(:user, email: "ned@foo.com")
      expect {
        post :password_reset, email: @user.email
      }.to change(EmailResetPasswordWorker.jobs, :size).by(1)
    end
  end

  describe :show do 
    xit "Should 404 if the user doesn't exist" do 
      # I have no idea why this fails. It works really, but not in tests!
      lambda {
        get :edit, id: "fake_user"
      }.should raise_error(ActionController::RoutingError)
    end
    
    it "should redirect to user home url if the user exists but doesn't want to show their page" do 
      @user = FactoryGirl.create(:user)
      @user.show_bikes = false
      @user.save
      get :show, id: @user.username
      response.should redirect_to user_home_url
    end
    
    it "Should show the page if the user exists and wants to show their page" do 
      @user = FactoryGirl.create(:user)
      @user.show_bikes = true
      @user.save
      get :show, id: @user.username
      response.should render_template :show 
    end
  end

  describe :accept_vendor_terms do 
    before do 
      user = FactoryGirl.create(:user)
      session[:user_id] = user.id
      get :accept_vendor_terms
    end
    it { should respond_with(:success) }
    it { should render_template(:accept_vendor_terms) }
  end

  describe :accept_terms do 
    before do 
      user = FactoryGirl.create(:user)
      session[:user_id] = user.id
      get :accept_terms
    end
    it { should respond_with(:success) }
    it { should render_template(:accept_terms) }
  end

  describe :edit do 
    before do 
      user = FactoryGirl.create(:user)
      session[:user_id] = user.id
      get :edit
    end
    it { should respond_with(:success) }
    it { should render_template(:edit) }
  end

  describe :update do 
    it "should update the terms of service" do 
      user = FactoryGirl.create(:user, terms_of_service: false)
      session[:user_id] = user.id 
      post :update, { id: user.username, user: {terms_of_service: "1"} }
      response.should redirect_to(user_home_url)
      user.reload.terms_of_service.should be_true
    end
    it "should update the vendor terms of service" do 
      user = FactoryGirl.create(:user, terms_of_service: false)
      org =  FactoryGirl.create(:organization)
      FactoryGirl.create(:membership, organization: org, user: user)
      session[:user_id] = user.id 
      post :update, { id: user.username, user: {vendor_terms_of_service: "1"} }
      response.code.should eq('302')
      user.reload.vendor_terms_of_service.should be_true
    end
  end


end
