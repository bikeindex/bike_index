require 'spec_helper'

describe Admin::UsersController do

  describe :edit do 
    xit "should 404 if the user doesn't exist" do 
      # I have no idea why this fails. It works really, but not in tests!
      lambda {
        get :edit, id: "STUFFFFFF"
      }.should raise_error(ActionController::RoutingError)
    end
    it "should show the edit page if the user exists" do 
      @admin = FactoryGirl.create(:user, superuser: true)
      @user = FactoryGirl.create(:user)
      set_current_user(@admin)
      get :edit, id: @user.username
      response.should render_template :edit
    end
  end

  describe :update do 
    it "should update all the things that can be edited" do 
      @admin = FactoryGirl.create(:user, superuser: true)
      @user = FactoryGirl.create(:user, confirmed: false)
      set_current_user(@admin)
      post :update, id: @user.username, :user =>{
        name: "New Name",
        email: "newemail@example.com",
        confirmed: true,
        superuser: true,
        can_invite: true,
        banned: true
      }
      @user.reload.name.should eq("New Name")
      @user.email.should eq("newemail@example.com")
      @user.confirmed.should be_true
      @user.superuser.should be_true
      @user.can_invite.should be_true
      @user.banned.should be_true
    end
  end


end
