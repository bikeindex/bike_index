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
      CreateUserJobs.new(user: user).associate_ownerships
      expect(ownership.reload.user_id).to eq(user.id)
      expect(ownership2.reload.user_id).to eq(user.id)
      expect(ownership3.reload.user_id).to eq(user.id)
    end
  end

  describe 'associate_membership_invites' do
    it 'assigns any organization invitations that match the user email, and mark user confirmed if invited' do
      organization_invitation = FactoryGirl.create(:organization_invitation, invitee_email: 'owNER1@a.com')
      user = FactoryGirl.create(:user, email: 'owner1@A.COM')
      CreateUserJobs.new(user: user).associate_membership_invites
      expect(user.reload.memberships.count).to eq(1)
      expect(user.confirmed).to be_truthy
    end
  end

  describe 'send_welcome_email' do
    it 'enques the email' do
      user = User.new
      allow(user).to receive(:id).and_return(69)
      CreateUserJobs.new(user: user).send_welcome_email
      expect(EmailWelcomeWorker).to have_enqueued_job(69)
    end
  end

  describe 'send_confirmation_email' do
    it 'enques the email' do
      user = User.new
      allow(user).to receive(:id).and_return(69)
      CreateUserJobs.new(user: user).send_confirmation_email
      expect(EmailConfirmationWorker).to have_enqueued_job(69)
    end
  end

  describe 'do_jobs' do
    it "calls associate_existing and send confirmation email if user isn't confirmed" do
      user = User.new
      create_user_jobs = CreateUserJobs.new(user: user)
      allow(user).to receive(:confirmed).and_return(false)
      expect(create_user_jobs).to receive(:associate_ownerships).and_return(true)
      expect(create_user_jobs).to receive(:associate_membership_invites).and_return(true)
      expect(create_user_jobs).to receive(:send_confirmation_email)
      create_user_jobs.do_jobs
    end

    it 'calls associate_existing and send welcome email if user is confirmed' do
      user = User.new
      create_user_jobs = CreateUserJobs.new(user: user)
      allow(user).to receive(:confirmed).and_return(true)
      expect(create_user_jobs).to receive(:associate_ownerships).and_return(true)
      expect(create_user_jobs).to receive(:associate_membership_invites).and_return(true)
      expect(create_user_jobs).to receive(:send_welcome_email)
      create_user_jobs.do_jobs
    end
  end
end
