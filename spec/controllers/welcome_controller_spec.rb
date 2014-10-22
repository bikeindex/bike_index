require 'spec_helper'

describe WelcomeController do

  describe :index do 
    before do 
      get :index
    end
    it { should respond_with(:success) }
    it { should render_template(:index) }
    it { should_not set_the_flash }
  end

  describe :goodbye do 
    before do 
      get :goodbye
    end
    it { should respond_with(:success) }
    it { should render_template(:goodbye) }
  end

  describe :user_home do 
    describe "user not present" do 
      before do 
        get :user_home
      end
      it { should respond_with(:redirect) }
      it { should redirect_to(new_session_url) }
      it { should set_the_flash }
    end

    describe "when user is present" do 
      before do 
        user = FactoryGirl.create(:user)
        session[:user_id] = user.id
        get :user_home
      end

      it { should_not set_the_flash }
      it { should respond_with(:success) }
      it { should render_template(:user_home) }
    end

    describe "user things should be assigned" do 
      it "sends the bikes and the locks" do 
        user = FactoryGirl.create(:user)
        ownership = FactoryGirl.create(:ownership, user: user, current: true)
        lock = FactoryGirl.create(:lock, user: user)
        session[:user_id] = user.id
        get :user_home
        assigns(:bikes).first.should eq(ownership.bike)
        assigns(:locks).first.should eq(lock)
      end
    end

  end



end
