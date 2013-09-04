require 'spec_helper'

describe MembershipsController do

  describe :edit do 
    it "should render the edit" do 
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      user2 = FactoryGirl.create(:user)
      membership = FactoryGirl.create(:membership, organization: organization, user: user, role: "admin")
      membership2 = FactoryGirl.create(:membership, organization: organization, user: user2)
      session[:user_id] = user.id
      { put: "/organizations/#{organization.slug}/memberships/#{membership.id}/edit" }
      response.code.should eq("200")
    end
  end

  describe :update do 
    it "should render the edit" do 
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      membership = FactoryGirl.create(:membership, organization: organization, user: user, role: "admin")
      put :update, {id: membership.id, :membership => {role: "admin"} }
      membership.role.should eq("admin")
    end
  end

end
