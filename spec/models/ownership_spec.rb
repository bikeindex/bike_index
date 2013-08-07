require "spec_helper"

describe Ownership do

  describe :validations do
    it { should belong_to :bike }
    it { should belong_to :user }
    it { should belong_to :creator }
    it { should validate_presence_of :creator_id }
    it { should validate_presence_of :owner_email }
  end

  describe :normalize_email do 
    it "should remove leading and trailing whitespace and downcase email" do 
      ownership = Ownership.new 
      ownership.stub(:owner_email).and_return("   SomE@dd.com ")
      ownership.normalize_email.should eq("some@dd.com")
    end
  end

  describe :mark_claimed do 
    it "Should associate with a user" do 
      o = FactoryGirl.create(:ownership)
      o.mark_claimed
      o.claimed.should be_true
    end
  end


  describe :owner do 
    it "should return the current owner if the ownership is claimed" do
      @user = FactoryGirl.create(:user)
      ownership = Ownership.new
      ownership.stub(:claimed).and_return(true)
      ownership.stub(:user).and_return(@user)
      ownership.owner.should eq(@user)
    end

    it "should return the creator if it isn't claimed" do 
      @user = FactoryGirl.create(:user)
      ownership = Ownership.new
      ownership.stub(:claimed).and_return(false)
      ownership.stub(:creator).and_return(@user)
      ownership.owner.should eq(@user)
    end
  end
end
