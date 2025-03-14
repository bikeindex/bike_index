require "rails_helper"

RSpec.describe EmailConfirmationJob, type: :job do
  before { stub_const("EmailConfirmationJob::PROCESS_NEW_EMAIL_DOMAINS", true) }

  it "sends a welcome email" do
    VCR.use_cassette("EmailConfirmationJob-default") do
      user = FactoryBot.create(:user)
      ActionMailer::Base.deliveries = []
      expect do
        EmailConfirmationJob.new.perform(user.id)
      end.to change(Notification, :count).by 1
      expect(ActionMailer::Base.deliveries.empty?).to be_falsey
    end
  end

  context "with email_domain" do
    let!(:email_domain) { FactoryBot.create(:email_domain, domain: "@rustymails.com", status:, user_count: 1) }
    let(:status) { "permitted" }
    let!(:user) { FactoryBot.create(:user, email: "something@rustymails.com") }

    it "creates the user" do
      expect(email_domain.reload.unprocessed?).to be_falsey
      expect(User.unscoped.count).to eq 2 # Because the admin from email_domain
      expect do
        EmailConfirmationJob.new.perform(user.id)
      end.to change(Notification, :count).by 1
      expect(ActionMailer::Base.deliveries.empty?).to be_falsey
    end

    context "pending" do
      let(:status) { "ban_pending" }
      it "does not send an email" do
        expect(User.unscoped.count).to eq 2 # Because the admin from email_domain
        ActionMailer::Base.deliveries = []
        expect do
          EmailConfirmationJob.new.perform(user.id)
        end.to change(Notification, :count).by 0
        expect(ActionMailer::Base.deliveries.empty?).to be_truthy
        expect(User.unscoped.count).to eq 2
        expect(UserLikelySpamReason.count).to eq 1
        expect(user.reload.likely_spam?).to be_truthy
        expect(user.user_likely_spam_reasons.first).to have_attributes(reason: "email_domain")
      end
    end

    context "banned" do
      let(:status) { "banned" }
      let!(:user_likely_spam_reason) { FactoryBot.create(:user_likely_spam_reason, user:) }

      it "does not send an email" do
        expect(User.unscoped.count).to eq 2 # Because the admin from email_domain
        ActionMailer::Base.deliveries = []
        expect do
          EmailConfirmationJob.new.perform(user.id)
        end.to change(Notification, :count).by 0
        expect(ActionMailer::Base.deliveries.empty?).to be_truthy
        expect(User.unscoped.count).to eq 1
        expect(UserLikelySpamReason.count).to eq 0 # It deletes the user
      end
    end
  end
  context "user with email already exists" do
    let!(:email_domain) { FactoryBot.create(:email_domain, domain: "bikeindex.org", status: "permitted", user_count: 1) }
    let(:email) { "test@bikeindex.org" }
    let!(:user1) { FactoryBot.create(:user, email: email) }
    let(:user2) do
      u = FactoryBot.create(:user)
      u.update_column :email, email
      u
    end
    it "deletes user" do
      expect(user1.email).to eq user2.email
      expect(user1.id).to be < user2.id
      ActionMailer::Base.deliveries = []
      expect {
        EmailConfirmationJob.new.perform(user2.id)
      }.to change(User, :count).by(-1)
      expect(ActionMailer::Base.deliveries.empty?).to be_truthy
    end
    context "calling other user" do
      it "does not delete the other user" do
        expect(user1.id).to be < user2.id
        ActionMailer::Base.deliveries = []
        expect {
          EmailConfirmationJob.new.perform(user1.id)
        }.to change(User, :count).by(0)
        expect(ActionMailer::Base.deliveries.empty?).to be_falsey
      end
    end
    context "recent notification" do
      let(:user) { FactoryBot.create(:user) }
      let!(:notification) { FactoryBot.create(:notification, kind: "confirmation_email", user: user, created_at: created_at, delivery_status: delivery_status) }
      let(:delivery_status) { "delivery_success" }
      let(:created_at) { Time.current - 30.seconds }
      it "doesn't resend" do
        ActionMailer::Base.deliveries = []
        expect {
          EmailConfirmationJob.new.perform(user.id)
        }.to change(Notification, :count).by(0)
        expect(ActionMailer::Base.deliveries.empty?).to be_truthy
      end
      context "sent 1:10 seconds ago" do
        let(:created_at) { Time.current - 70.seconds }
        it "resends" do
          ActionMailer::Base.deliveries = []
          expect {
            EmailConfirmationJob.new.perform(user.id)
          }.to change(Notification, :count).by(1)
          expect(ActionMailer::Base.deliveries.empty?).to be_falsey
          notification2 = Notification.last
          expect(notification2.user).to eq user
          expect(notification2.delivery_status).to eq "delivery_success"
        end
      end
      context "delivery_status pending" do
        let(:delivery_status) { "delivery_pending" }
        it "resends, updates existing notification" do
          ActionMailer::Base.deliveries = []
          expect {
            EmailConfirmationJob.new.perform(user.id)
          }.to change(Notification, :count).by(0)
          expect(ActionMailer::Base.deliveries.empty?).to be_falsey
          notification.reload
          expect(notification.delivery_success?).to be_truthy
        end
      end
    end
  end
end
