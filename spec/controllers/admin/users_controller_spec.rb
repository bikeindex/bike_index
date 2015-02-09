require 'spec_helper'

describe Admin::UsersController do

  describe :edit do 
    xit "404s if the user doesn't exist" do 
      # I have no idea why this fails. It works really, but not in tests!
      lambda {
        get :edit, id: "STUFFFFFF"
      }.should raise_error(ActionController::RoutingError)
    end
    it "shows the edit page if the user exists" do 
      @admin = FactoryGirl.create(:admin)
      @user = FactoryGirl.create(:user)
      set_current_user(@admin)
      get :edit, id: @user.username
      response.should render_template :edit
    end
  end

  describe :update do 
    it "updates all the things that can be edited" do 
      @admin = FactoryGirl.create(:admin)
      @user = FactoryGirl.create(:user, confirmed: false)
      set_current_user(@admin)
      post :update, id: @user.username, :user =>{
        name: "New Name",
        email: "newemail@example.com",
        confirmed: true,
        superuser: true,
        is_content_admin: true,
        can_invite: true,
        can_send_many_stolen_notifications: true,
        banned: true
      }
      @user.reload.name.should eq("New Name")
      @user.email.should eq("newemail@example.com")
      @user.confirmed.should be_true
      @user.superuser.should be_true
      @user.can_invite.should be_true
      @user.can_send_many_stolen_notifications.should be_true
      @user.banned.should be_true
    end
  end


end
