require "spec_helper"

describe AfterUserCreateWorker do
  let(:subject) { AfterUserCreateWorker }
  let(:instance) { subject.new }

  it { is_expected.to be_processed_in :updates }

  let!(:user) { FactoryGirl.create(:user, email: "owner1@A.COM") }
  let(:email) { user.email }

  describe "perform" do
    context "state: new" do
      let(:user) { User.new(id: 69, email: "owner@jess.com") }
      it "sends confirmation email" do
        expect(instance).to receive(:associate_membership_invites).and_return(true)
        instance.perform(user.id, "new", user: user)
        expect(EmailConfirmationWorker).to have_enqueued_sidekiq_job(69)
      end

      context "confirmed user" do
        it "sends welcome email" do
          allow(user).to receive(:confirmed?) { true }
          instance.perform(user.id, "new", user: user)
          expect(EmailWelcomeWorker).to have_enqueued_sidekiq_job(69)
        end
      end
    end

    context "state: confirmed" do
      it "associates" do
        expect(UserEmail).to receive(:create_confirmed_primary_email).with(user)
        expect(instance).to receive(:associate_ownerships)
        instance.perform(user.id, "confirmed", user: user)
      end
    end

    context "state: merged" do
      it "associates" do
        expect(instance).to receive(:associate_ownerships)
        expect(instance).to receive(:associate_membership_invites)
        instance.perform(user.id, "merged", user: user)
      end
    end
  end

  describe "associate_ownerships" do
    let(:bike) { FactoryGirl.create(:bike, owner_email: "owner1@a.com") }
    let!(:ownership) { FactoryGirl.create(:ownership, owner_email: "OWner1@a.com", bike: bike) }
    let(:bike2) { FactoryGirl.create(:bike, owner_email: "owner1@a.com") }
    let!(:ownership2) { FactoryGirl.create(:ownership, owner_email: "owner1@a.com", bike: bike2) }
    let(:bike3) { FactoryGirl.create(:bike, owner_email: "owner1@a.com") }
    let!(:ownership3) { FactoryGirl.create(:ownership, owner_email: "owner1@a.com", bike: bike3) }

    it "assigns any ownerships that match the user email" do
      expect(user).to be_present
      ownerships = [ownership, ownership2, ownership3]
      ownerships.each { |o| expect(o.user).to be_nil }
      instance.associate_ownerships(user, email)

      ownerships.each do |o|
        o.reload
        expect(o.user).to eq user
      end
    end
  end

  describe "associate_membership_invites" do
    let!(:organization_invitation) { FactoryGirl.create(:organization_invitation, invitee_email: " #{user.email.upcase}") }
    let(:user) { FactoryGirl.build(:user, email: "owner1@A.COM") }
    it "assigns any organization invitations that match the user email, and mark user confirmed if invited" do
      user.save
      expect(organization_invitation.created_at < user.created_at).to be_truthy
      # This is called on create, so we just test that things happen correctly here
      # Rather than stubbing stuff out - and to ensure that this actually happens inline
      user.reload
      expect(user.memberships.count).to eq 1
      expect(user.confirmed?).to be_truthy
    end
  end

  describe "send_welcoming_email" do
    let(:user) { User.new(id: 69) }
    it "enques enqueues confirmation email" do
      instance.send_welcoming_email(user)
      expect(EmailConfirmationWorker).to have_enqueued_sidekiq_job(69)
    end
    context "confirmed user" do
      it "enques welcome email" do
        allow(user).to receive(:confirmed?) { true }
        instance.send_welcoming_email(user)
        expect(EmailWelcomeWorker).to have_enqueued_sidekiq_job(69)
      end
    end
  end
end
