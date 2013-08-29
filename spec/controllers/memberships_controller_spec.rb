require 'spec_helper'

describe MembershipsController do

  # describe :destroy do 
  #   before do
  #     organization = FactoryGirl.create(:organization)
  #     user = FactoryGirl.create(:user)
  #     membership = FactoryGirl.create(:membership, organization: organization, user: user)      
  #     ApplicationController.any_instance.should_receive(:authenticate_user!).and_return(true)
  #     ApplicationController.any_instance.should_receive(:current_organization).and_return(organization)
  #     controller.should_receive(:find_organization_mem!).and_return(true)
  #     put :destroy, id: membership.id
  #   end
  #   it { should redirect_to(:root) }
  #   it { should set_the_flash }
  # end

  # describe :update do 
  #   before do
  #     organization = FactoryGirl.create(:organization)
  #     @user = FactoryGirl.create(:user)
  #     membership = FactoryGirl.create(:membership, organization: organization, user: @user)      
  #     ApplicationController.any_instance.should_receive(:authenticate_user!).and_return(true)
  #     put :update, {id: membership.id, :membership => {role: "admin"} }
  #   end
  #   it { should redirect_to("/users/#{@user.username}") }
  #   it { should set_the_flash }
  # end

  describe :edit do 
    it "should render the edit" do 
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      user2 = FactoryGirl.create(:user)
      membership = FactoryGirl.create(:membership, organization: organization, user: user, role: "admin")
      membership2 = FactoryGirl.create(:membership, organization: organization, user: user2)
      # ApplicationController.any_instance.should_receive(:authenticate_user!).and_return(true)
      session[:user_id] = user.id
      { put: "/organizations/#{organization.slug}/memberships/#{membership.id}/edit" }
      response.code.should eq("200")
    end
  end

  describe :update do 
    it "should render the edit" do 
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      user2 = FactoryGirl.create(:user)
      membership = FactoryGirl.create(:membership, organization: organization, user: user, role: "admin")
      membership2 = FactoryGirl.create(:membership, organization: organization, user: user2, role: "member")
      session[:user_id] = user.id
      { put: :update, "/organizations/#{organization.slug}/memberships/#{membership.id}", :membership => {role: "admin"} }
      membership2.role.should eq("admin")
    end
  end

end
