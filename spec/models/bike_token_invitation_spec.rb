require 'spec_helper'

describe BikeTokenInvitation do

  describe :validations do
    it "requires an invitee_email, message, subject, bike_token_count, and an inviter" do
      bt = BikeTokenInvitation.new(message: nil, subject: nil, bike_token_count: nil) # There are defaults, we have to nil them to test validation
      bt.valid?.should be_false
      bt.errors.messages[:invitee_email].should be_present
      bt.errors.messages[:inviter].should be_present
      bt.errors.messages[:subject].should be_present
      bt.errors.messages[:message].should be_present
      bt.errors.messages[:bike_token_count].should be_present
    end
  end

  describe :create do
    before :each do
      @bt = FactoryGirl.create(:bike_token_invitation)
    end

    it "creates a valid bike_token_invitation" do 
      @bt.valid?.should be_true
    end

    it "creates a bike token if the user exists, and mark itself claimed" do 
      @user = FactoryGirl.create(:user)
      @bt1 = FactoryGirl.create(:bike_token_invitation, invitee_email: @user.email)
      @user.bike_tokens.count.should eq(1)
      @bt1.redeemed.should be_true
    end
  end

  describe :normalize_email do 
    it "removes leading and trailing whitespace and downcase email" do 
      bt = BikeTokenInvitation.new 
      bt.stub(:invitee_email).and_return("   SomE@dd.com ")
      bt.normalize_email.should eq("some@dd.com")
    end
  end


  describe "assign_to(user)" do 

    before :each do
      @bti = FactoryGirl.create(:bike_token_invitation, invitee_email: "stuff@email.com")
      @user = FactoryGirl.create(:user, email: "stuff@email.com")
    end

    it "sets the user if the email does match" do
      @bti.assign_to(@user)
      @bti.invitee.id.should eq(@user.id)
    end

    it "sets bike token invitation to redeemed true" do
      @bti.assign_to(@user)
      @bti.redeemed.should be_true
    end
    
    it "is not able to be used again once it has been redeemed" do
      @bti.assign_to(@user)
      @user.bike_tokens.count.should eq(1)
      @bti.assign_to(@user)
      @user.bike_tokens.count.should eq(1)
    end

    it "creates a bike_token_count number of bike_tokens" do 
      @bti1 = FactoryGirl.create(:bike_token_invitation, invitee_email: "stuff@email.com", bike_token_count: 10)
      @bti1.assign_to(@user)
      @user.bike_tokens.count.should eq(10)
    end

  end

end
