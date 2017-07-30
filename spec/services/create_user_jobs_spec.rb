require 'spec_helper'

describe CreateUserJobs do
  describe 'associate_ownerships' do
    it 'assigns any ownerships that match the user email' do
      bike = FactoryGirl.create(:bike, owner_email: 'owner1@a.com')
      ownership = FactoryGirl.create(:ownership, owner_email: 'OWner1@a.com', bike: bike)
      bike2 = FactoryGirl.create(:bike, owner_email: 'owner1@a.com')
      ownership2 = FactoryGirl.create(:ownership, owner_email: 'owner1@a.com', bike: bike2)
      bike3 = FactoryGirl.create(:bike, owner_email: 'owner1@a.com')
      ownership3 = FactoryGirl.create(:ownership, owner_email: 'owner1@a.com', bike: bike3)
      user = FactoryGirl.create(:user, email: 'owner1@A.COM')
      CreateUserJobs.new(user).associate_ownerships
      expect(ownership.reload.user_id).to eq(user.id)
      expect(ownership2.reload.user_id).to eq(user.id)
      expect(ownership3.reload.user_id).to eq(user.id)
    end
  end

  describe 'associate_membership_invites' do
    it 'assigns any organization invitations that match the user email, and mark user confirmed if invited' do
      # This is called on create, so we just test that things happen correctly here
      # Rather than stubbing stuff out
      organization_invitation = FactoryGirl.create(:organization_invitation, invitee_email: 'owNER1@a.com')
      user = FactoryGirl.create(:user, email: 'owner1@A.COM')
      user.reload
      expect(user.memberships.count).to eq 1
      expect(user.confirmed).to be_truthy
    end
  end

  describe 'send_welcome_email' do
    it 'enques the email' do
      user = User.new
      allow(user).to receive(:id).and_return(69)
      CreateUserJobs.new(user).send_welcome_email
      expect(EmailWelcomeWorker).to have_enqueued_sidekiq_job(69)
    end
  end

  describe 'send_confirmation_email' do
    it 'enques the email' do
      user = User.new
      allow(user).to receive(:id).and_return(69)
      CreateUserJobs.new(user).send_confirmation_email
      expect(EmailConfirmationWorker).to have_enqueued_sidekiq_job(69)
    end
  end

  describe 'perform_create_jobs' do
    it "sends confirmation email if user isn't confirmed" do
      user = User.new
      create_user_jobs = CreateUserJobs.new(user)
      expect(create_user_jobs).to receive(:associate_membership_invites).and_return(true)
      allow(user).to receive(:confirmed).and_return(false)
      expect(create_user_jobs).to receive(:send_confirmation_email).and_return(true)
      create_user_jobs.perform_create_jobs
    end

    it 'sends welcome email and performs confirmed jobs if user is confirmed' do
      user = User.new
      create_user_jobs = CreateUserJobs.new(user)
      allow(user).to receive(:confirmed).and_return(true)
      expect(UserEmail).to receive(:create_confirmed_primary_email).with user
      expect(create_user_jobs).to receive(:associate_ownerships).and_return(true)
      expect(create_user_jobs).to receive(:associate_membership_invites).and_return(true)
      expect(create_user_jobs).to receive(:send_welcome_email).and_return(true)
      create_user_jobs.perform_create_jobs
    end
  end

  describe 'perform_confirmed_jobs' do
    it 'creates confirmed email, associates' do
      user = User.new
      create_user_jobs = CreateUserJobs.new(user)
      allow(user).to receive(:confirmed).and_return(true)
      expect(UserEmail).to receive(:create_confirmed_primary_email).with(user).and_return(true)
      expect(create_user_jobs).to receive(:associate_ownerships).and_return(true)
      create_user_jobs.perform_confirmed_jobs
    end
  end
end
