require 'spec_helper'

describe CreateUserJobs do

  describe :associate_ownerships do
    it "should assign any ownerships that match the user email" do
      bike = FactoryGirl.create(:bike, owner_email: "owner1@a.com")
      ownership = FactoryGirl.create(:ownership, owner_email: "OWner1@a.com", bike: bike)
      bike2 = FactoryGirl.create(:bike, owner_email: "owner1@a.com")
      ownership2 = FactoryGirl.create(:ownership, owner_email: "owner1@a.com", bike: bike2)
      bike3 = FactoryGirl.create(:bike, owner_email: "owner1@a.com")
      ownership3 = FactoryGirl.create(:ownership, owner_email: "owner1@a.com", bike: bike3)
      user = FactoryGirl.create(:user, email: "owner1@A.COM")
      CreateUserJobs.new(user: user).associate_ownerships
      ownership.reload.user_id.should eq(user.id)
      ownership2.reload.user_id.should eq(user.id)
      ownership3.reload.user_id.should eq(user.id)
    end
  end

  describe :associate_token_invites do
    it "should assign any bike token invitations that match the user email" do 
      @bike_token_invitation = FactoryGirl.create(:bike_token_invitation, invitee_email: "owner1@a.com", bike_token_count: 13)
      @user = FactoryGirl.create(:user, email: "owner1@A.COM")
      CreateUserJobs.new(user: @user).associate_token_invites
      @user.reload.bike_tokens.count.should eq(13)
    end
  end

  describe :associate_membership_invites do 
    it "should assign any organization invitations that match the user email" do 
      @organization_invitation = FactoryGirl.create(:organization_invitation, invitee_email: "owNER1@a.com")
      @user = FactoryGirl.create(:user, email: "owner1@A.COM")
      CreateUserJobs.new(user: @user).associate_membership_invites
      @user.reload.memberships.count.should eq(1)
    end
  end

  describe :send_welcome_email do 
    it "should enque the email" do 
      user = User.new
      user.stub(:id).and_return(69)
      CreateUserJobs.new(user: user).send_welcome_email
      WelcomeEmailJob.should have_queued(69)
    end
  end

  describe :send_confirmation_email do 
    it "should enque the email" do 
      user = User.new
      user.stub(:id).and_return(69)
      CreateUserJobs.new(user: user).send_confirmation_email
      ConfirmationEmailJob.should have_queued(69)
    end
  end

  describe :do_jobs do 
    it "should call associate_existing and send confirmation email if user isn't confirmed" do 
      user = User.new
      create_user_jobs = CreateUserJobs.new(user: user)
      user.stub(:confirmed).and_return(false)
      create_user_jobs.should_receive(:associate_ownerships).and_return(true)
      create_user_jobs.should_receive(:associate_token_invites).and_return(true)
      create_user_jobs.should_receive(:associate_membership_invites).and_return(true)
      create_user_jobs.should_receive(:send_confirmation_email)
      create_user_jobs.do_jobs
    end

    it "should call associate_existing and send welcome email if user is confirmed" do 
      user = User.new
      create_user_jobs = CreateUserJobs.new(user: user)
      user.stub(:confirmed).and_return(true)
      create_user_jobs.should_receive(:associate_ownerships).and_return(true)
      create_user_jobs.should_receive(:associate_token_invites).and_return(true)
      create_user_jobs.should_receive(:associate_membership_invites).and_return(true)
      create_user_jobs.should_receive(:send_welcome_email)
      create_user_jobs.do_jobs
    end
  end

  


end