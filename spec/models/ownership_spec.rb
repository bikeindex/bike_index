require "spec_helper"

describe Ownership do

  describe :validations do
    it { should belong_to :bike }
    it { should belong_to :user }
    it { should belong_to :creator }
    it { should validate_presence_of :creator_id }
    it { should validate_presence_of :bike_id }
    it { should validate_presence_of :owner_email }
  end

  describe :normalize_email do 
    it "removes leading and trailing whitespace and downcase email" do 
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
    it "returns the current owner if the ownership is claimed" do
      @user = FactoryGirl.create(:user)
      ownership = Ownership.new
      ownership.stub(:claimed).and_return(true)
      ownership.stub(:user).and_return(@user)
      ownership.owner.should eq(@user)
    end

    it "returns the creator if it isn't claimed" do 
      @user = FactoryGirl.create(:user)
      ownership = Ownership.new
      ownership.stub(:claimed).and_return(false)
      ownership.stub(:creator).and_return(@user)
      ownership.owner.should eq(@user)
    end
  end

  describe :can_be_claimed_by do 
    it "true if user email matches" do 
      user = FactoryGirl.create(:user)
      ownership = Ownership.new(owner_email: " #{user.email.upcase}")
      ownership.can_be_claimed_by(user).should be_true
    end
    it "true if user matches" do 
      user = FactoryGirl.create(:user)
      ownership = Ownership.new(user_id: user.id)
      ownership.can_be_claimed_by(user).should be_true
    end
    it "false if it can't be claimed by user" do 
      user = FactoryGirl.create(:user)
      ownership = Ownership.new(owner_email: "fake#{user.email.titleize}")
      ownership.can_be_claimed_by(user).should be_false
    end
  end

end
