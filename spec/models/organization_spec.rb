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

end
