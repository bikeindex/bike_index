require 'spec_helper'

describe Organization do
  it "should require a default discount" do
    @organization = Organization.new
    @organization.valid?.should be_false
    @organization.errors.messages[:name].should be_present
  end

  
  describe :set_urls do
    it "should not add http:// to the website if the url doesn't have it so that the link goes somewhere" do
      @user = FactoryGirl.create(:organization, website: "somewhere.org" )
      @user.website.should eq('somewhere.org')
    end
    xit "should remove http:// from the website url if it's already there" do
      @user = FactoryGirl.create(:organization, website: "http://somewhere.com" )
      @user.website.should eq('somewhere.com')
    end
  end

  describe :set_embedable_user do 
    it "should set the embedable user" do 
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user, email: "embed@org.com")
      membership = FactoryGirl.create(:membership, organization: organization, user: user)
      organization.embedable_user_email = "embed@org.com"
      organization.save
      organization.reload.embedable_user_id.should eq(user.id)
    end
    it "should not set the embedable user if user is not a member" do 
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user, email: "no_embed@org.com")
      organization.embedable_user_email = "no_embed@org.com"
      organization.save
      organization.reload.embedable_user_id.should be_nil
    end
  end

end
