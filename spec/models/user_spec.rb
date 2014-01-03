require 'spec_helper'

describe User do
 
  describe :validate do
    describe :create do
      before :each do
        @user = User.new(FactoryGirl.attributes_for(:user))
        @user.valid?.should be_true
      end

      it "should require password on create" do 
        @user.password = nil
        @user.password_confirmation = nil
        @user.valid?.should be_false
        @user.errors.messages[:password].include?("can't be blank").should be_true
      end

      it "should require password and confirmation to match" do
        @user.password_confirmation = "wtf"
        @user.valid?.should be_false
        @user.errors.messages[:password].include?("doesn't match confirmation").should be_true
      end

      it "should require at least 8 characters for the password" do
        @user.password = 'hi'
        @user.password_confirmation = 'hi'
        @user.valid?.should be_false
        @user.errors.messages[:password].include?('is too short (minimum is 6 characters)').should be_true
      end

      it "should make sure there is at least one letter" do
        @user.password = '1234567890'
        @user.password_confirmation = '1234567890'
        @user.valid?.should be_false
        @user.errors.messages[:password].include?('must contain at least one letter').should be_true
      end

    end

    describe :confirm do
      before :each do
        @user = FactoryGirl.create(:user)
      end

      it "should require confirmation" do
        @user.confirmed.should be_false
        @user.confirmation_token.should_not be_nil
      end

      it "should confirm users" do
        @user.confirm(@user.confirmation_token).should be_true
        @user.confirmed.should be_true
        @user.confirmation_token.should be_nil
      end

      it "should fail to confirm users" do
        @user.confirm("wtfmate").should be_false
        @user.confirmed.should be_false
        @user.confirmation_token.should_not be_nil
      end

      it "should be bannable" do
        @user.banned = true
        @user.save
        @user.authenticate('testme21').should == false
      end
    end

    describe :update
      before :each do
        @user = FactoryGirl.create(:user)
        @user.valid?.should be_true
      end

      it "should not require a password on update" do
        @user.save
        @user.password = nil
        @user.password_confirmation = nil
        @user.valid?.should be_true
      end


      it "should require password and confirmation to match" do
        @user.password_confirmation = "wtf"
        @user.valid?.should be_false
        @user.errors.messages[:password].include?("doesn't match confirmation").should be_true
      end

      it "should require at least 8 characters for the password" do
        @user.password = 'hi'
        @user.password_confirmation = 'hi'
        @user.valid?.should be_false
        @user.errors.messages[:password].include?('is too short (minimum is 6 characters)').should be_true
      end

      it "should make sure there is at least one letter" do
        @user.password = '1234567890'
        @user.password_confirmation = '1234567890'
        @user.valid?.should be_false
        @user.errors.messages[:password].include?('must contain at least one letter').should be_true
      end
  end

  describe :fuzzy_email_find do
    it "should find users by email address when the case doesn't match" do
      @user = FactoryGirl.create(:user, email: "ned@foo.com")
      User.fuzzy_email_find('NeD@fOO.coM').should == @user
    end
  end

  describe :set_urls do
    xit "should add http:// to twitter and website if the url doesn't have it so that the link goes somewhere" do
      @user = FactoryGirl.create(:user, show_twitter: true, twitter: "http://somewhere.com", show_website: true, website: "somewhere.org" )
      @user.website.should eq('http://somewhere.org')
    end
    it "should not add http:// to twitter if it's already there" do
      @user = FactoryGirl.create(:user, show_twitter: true, twitter: "http://somewhere.com", show_website: true, website: "somewhere" )
      @user.twitter.should eq('http://somewhere.com')
    end
  end

  describe :set_phone do
    it "should strip the non-digit numbers from the phone input" do
      @user = FactoryGirl.create(:user, phone: '773.83ddp+83(887)')
      @user.phone.should eq('7738383887')
    end
  end

  describe :bikes do
    it "should return nil if the user has no bikes" do
      user = FactoryGirl.create(:user)
      user.bikes.should be_empty
    end
    it "should return the user's bikes if they have any" do
      user = FactoryGirl.create(:user)
      o = FactoryGirl.create(:ownership, owner_email: user.email, user_id: user.id)
      user.bikes.should include(o.bike.id)
    end
  end

  describe :available_bike_tokens do
    before :each do
      @organization = FactoryGirl.create(:organization)
      @user = FactoryGirl.create(:user)
      5.times do
        FactoryGirl.create(:bike_token, user: @user, organization: @organization)
      end
      @bike = FactoryGirl.create(:bike)
    end

    it "should return the available bike tokens" do
      @user.available_bike_tokens.count.should eq(5)
      @user.available_bike_tokens.first.destroy
      @user.available_bike_tokens.count.should eq(4)
      @user.available_bike_tokens.first.update_column(:bike_id, @bike)
      @user.available_bike_tokens.count.should eq(3)
    end
  end

end
