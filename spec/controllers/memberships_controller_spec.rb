require 'spec_helper'

describe MembershipsController do

  describe :destroy do 
    before do
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      membership = FactoryGirl.create(:membership, organization: organization, user: user)      
      ApplicationController.any_instance.should_receive(:authenticate_user!).and_return(true)
      ApplicationController.any_instance.should_receive(:current_organization).and_return(organization)
      controller.should_receive(:require_admin_of_membership!).and_return(true)
      put :destroy, id: membership.id
    end
    it { should redirect_to(:root) }
    it { should set_the_flash }
  end

  describe :update do 
    before do
      organization = FactoryGirl.create(:organization)
      @user = FactoryGirl.create(:user)
      membership = FactoryGirl.create(:membership, organization: organization, user: @user)      
      ApplicationController.any_instance.should_receive(:authenticate_user!).and_return(true)
      controller.should_receive(:require_admin_of_membership!).and_return(true)
      put :update, {id: membership.id, :membership => {role: "admin"} }
    end
    it { should redirect_to("/users/#{@user.username}") }
    it { should set_the_flash }
  end

end
