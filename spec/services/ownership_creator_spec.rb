require 'spec_helper'

describe OwnershipCreator do
  describe :owner_id do 
    it "finds the user" do 
      user = FactoryGirl.create(:user, email: "foo@email.com")
      create_ownership = OwnershipCreator.new
      create_ownership.stub(:find_owner_email).and_return("foo@email.com")
      create_ownership.owner_id.should eq(user.id)
    end
    it "returns false if the user doesn't exist" do 
      create_ownership = OwnershipCreator.new()
      create_ownership.stub(:find_owner_email).and_return("foo")
      create_ownership.owner_id.should be_nil
    end
  end

  describe :find_owner_email do 
    it "is the bike params unless owner_email is present" do 
      bike = Bike.new
      bike.stub(:owner_email).and_return("foo@email.com")
      OwnershipCreator.new(bike: bike).find_owner_email.should eq("foo@email.com")
    end
  end

  describe :send_notification_email do 
    it "sends a notification email" do 
      ownership = Ownership.new
      ownership.stub(:id).and_return(2)
      expect {
        OwnershipCreator.new().send_notification_email(ownership)
      }.to change(EmailOwnershipInvitationWorker.jobs, :size).by(1)
    end

    it "does not send a notification email for example bikes" do 
      ownership = Ownership.new
      ownership.stub(:id).and_return(2)
      ownership.stub(:example).and_return(true)
      expect {
        OwnershipCreator.new().send_notification_email(ownership)
      }.to change(EmailOwnershipInvitationWorker.jobs, :size).by(0)
    end

    it "does not send a notification email for ownerships with no_email set" do 
      ownership = Ownership.new
      ownership.stub(:id).and_return(2)
      ownership.stub(:send_email).and_return(false)
      expect {
        OwnershipCreator.new().send_notification_email(ownership)
      }.to change(EmailOwnershipInvitationWorker.jobs, :size).by(0)
    end
  end

  describe :new_ownership_params do
    it "creates new ownership attributes" do 
      user = User.new
      bike = Bike.new 
      user.stub(:id).and_return(69)
      bike.stub(:example).and_return(true)
      bike.stub(:id).and_return(1)
      create_ownership = OwnershipCreator.new(creator: user, bike: bike)
      create_ownership.stub(:owner_id).and_return(69)
      create_ownership.stub(:self_made?).and_return(false)
      create_ownership.stub(:find_owner_email).and_return("f@f.com")
      new_params = create_ownership.new_ownership_params
      new_params[:bike_id].should eq(1)
      new_params[:example].should eq(true)
      new_params[:user_id].should eq(69)
      new_params[:owner_email].should eq("f@f.com")
      new_params[:claimed].should be_false
      new_params[:current].should be_true
    end

    it "creates a current new ownership if the ownership is created by the same person" do 
      user = User.new
      bike = Bike.new 
      user.stub(:id).and_return(69)
      bike.stub(:id).and_return(1)
      create_ownership = OwnershipCreator.new(creator: user, bike: bike)
      create_ownership.stub(:owner_id).and_return(69)
      create_ownership.stub(:self_made?).and_return(true)
      create_ownership.stub(:find_owner_email).and_return("f@f.com")
      new_params = create_ownership.new_ownership_params
      new_params[:bike_id].should eq(1)
      new_params[:user_id].should eq(69)
      new_params[:owner_email].should eq("f@f.com")
      new_params[:claimed].should be_true
      new_params[:current].should be_true
    end
  end

  describe :mark_other_ownerships_not_current do 
    it "marks existing ownerships as not current" do 
      ownership1 = FactoryGirl.create(:ownership)
      bike = ownership1.bike 
      ownership2 = FactoryGirl.create(:ownership, bike: bike)
      create_ownership = OwnershipCreator.new(bike: bike).mark_other_ownerships_not_current
      ownership1.reload.current.should be_false
      ownership2.reload.current.should be_false
    end
  end

  describe :add_errors_to_bike do 
    xit "should add the errors to the bike" do 
      ownership = Ownership.new 
      bike = Bike.new 
      ownership.errors.add(:problem, "BALLZ")
      creator = OwnershipCreator.new(bike: bike)
      creator.add_errors_to_bike(ownership)
      bike.errors.messages[:problem].should eq("BALLZ")
    end
  end

  describe :create_ownership do
    it "calls mark not current and send notification and create a new ownership" do
      create_ownership = OwnershipCreator.new()
      new_params = {bike_id: 1,user_id: 69, owner_email: "f@f.com", creator_id: 69,claimed: true, current: true}
      create_ownership.stub(:mark_other_ownerships_not_current).and_return(true)
      create_ownership.stub(:new_ownership_params).and_return(new_params)
      create_ownership.should_receive(:send_notification_email).and_return(true)
      lambda { create_ownership.create_ownership }.should change(Ownership, :count).by(1)
    end
    it "calls mark not current and send notification and create a new ownership" do
      create_ownership = OwnershipCreator.new()
      new_params = {creator_id: 69, claimed: true, current: true}
      create_ownership.stub(:mark_other_ownerships_not_current).and_return(true)
      create_ownership.stub(:new_ownership_params).and_return(new_params)
      create_ownership.should_receive(:add_errors_to_bike).and_return(true)
      expect{ create_ownership.create_ownership }.to raise_error(OwnershipNotSavedError)
    end
  end


end
