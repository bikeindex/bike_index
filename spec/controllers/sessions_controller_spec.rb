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
          session[:user_id].should == @user.id
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
      session[:user_id].should be_nil
    end

    it "does not log in the user when the user is not found" do
      post :create, session: { email: "notThere@example.com" }
      session[:user_id].should be_nil
      response.should render_template(:new)
    end
  end


  describe :logout do
    it "logs out the current user" do
      session[:user_id] = 4
      get :destroy
      session[:user_id].should be_nil
      response.should redirect_to goodbye_url
    end
  end
end
