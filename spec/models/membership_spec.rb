require 'spec_helper'


describe Membership do
  describe :create do
    before :each do
      @organization = FactoryGirl.create(:organization)
      @user = FactoryGirl.create(:user)
    end

    it "adds bike tokens on create" do
      lambda {
        FactoryGirl.create(:membership, organization: @organization, user: @user)
      }.should change(BikeToken, :count).by(5)
    end

    it "Should not give them tokens if they have 5 or more tokens already" do
      @organization2 = FactoryGirl.create(:organization)
      FactoryGirl.create(:membership, organization: @organization, user: @user)
      FactoryGirl.create(:membership, organization: @organization2, user: @user)
      @user.bike_tokens.count.should eq(5)
    end
  end
end
