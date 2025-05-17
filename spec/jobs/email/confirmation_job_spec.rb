require "rails_helper"

RSpec.describe Email::ConfirmationJob, type: :job do
  before { stub_const("EmailDomain::VERIFICATION_ENABLED", true) }

  it "sends a welcome email" do
    VCR.use_cassette("Email::ConfirmationJob-default") do
      user = FactoryBot.create(:user)
      ActionMailer::Base.deliveries = []
      expect do
        Email::ConfirmationJob.new.perform(user.id)
      end.to change(Notification, :count).by 1
      expect(ActionMailer::Base.deliveries.empty?).to be_falsey
    end
  end

  context "with email_domain" do
    let!(:email_domain) { FactoryBot.create(:email_domain, domain: "@rustymails.com", status:, user_count: 1) }
    let(:status) { "permitted" }
    let!(:user) { FactoryBot.create(:user, email: "something@rustymails.com") }

    it "creates the user and sends the email" do
      expect(email_domain.reload.unprocessed?).to be_falsey
      expect(User.unscoped.count).to eq 2 # Because the admin from email_domain
      expect do
        Email::ConfirmationJob.new.perform(user.id)
      end.to change(Notification, :count).by 1
      expect(ActionMailer::Base.deliveries.empty?).to be_falsey
    end

    context "pending" do
      let(:status) { "provisional_ban" }
      it "does not send an email" do
        expect(User.unscoped.count).to eq 2 # Because the admin from email_domain
        ActionMailer::Base.deliveries = []
        expect do
          Email::ConfirmationJob.new.perform(user.id)
        end.to change(Notification, :count).by 0
        expect(ActionMailer::Base.deliveries.empty?).to be_truthy
        expect(User.unscoped.count).to eq 2
        expect(EmailBan.count).to eq 1
        expect(user.reload.email_banned?).to be_truthy
        expect(user.email_bans.first).to have_attributes(reason: "email_domain")
      end
    end

    context "banned" do
      let(:status) { "banned" }
      let!(:email_ban) { FactoryBot.create(:email_ban, user:) }

      it "does not send an email" do
        expect(User.unscoped.count).to eq 2 # Because the admin from email_domain
        ActionMailer::Base.deliveries = []
        expect do
          Email::ConfirmationJob.new.perform(user.id)
        end.to change(Notification, :count).by 0
        expect(ActionMailer::Base.deliveries.empty?).to be_truthy
        expect(User.unscoped.count).to eq 1
        expect(EmailBan.count).to eq 0 # It deletes the user
      end
    end
  end

  context "with an email with periods in different places" do
    let!(:user_prior) { FactoryBot.create(:user, email: "someth.i.ng@g.mail.com", created_at:) }
    let(:created_at) { Time.current - 12.hours }
    let!(:user) { FactoryBot.create(:user, email: "something@g.mail.com") }

    it "creates a ban and doesn't notify" do
      expect(User.unscoped.count).to eq 2 # Because the admin from email_domain
      ActionMailer::Base.deliveries = []
      expect do
        VCR.use_cassette("Email::ConfirmationJob-g.mail") do
          Email::ConfirmationJob.new.perform(user.id)
        end
      end.to change(Notification, :count).by 0
      expect(ActionMailer::Base.deliveries.empty?).to be_truthy
      expect(User.unscoped.count).to eq 2
      expect(EmailBan.count).to eq 1
      expect(user.reload.email_banned?).to be_truthy
      expect(user.email_bans.first).to have_attributes(reason: "email_duplicate")
    end

    context "before period" do
      let(:created_at) { Time.current - 14.days }
      it "creates the user and sends the email" do
        expect(User.unscoped.count).to eq 2
        expect do
          VCR.use_cassette("Email::ConfirmationJob-g.mail") do
            Email::ConfirmationJob.new.perform(user.id)
          end
        end.to change(Notification, :count).by 1
        expect(ActionMailer::Base.deliveries.empty?).to be_falsey
      end

      context "with > PRE_PERIOD_DUPLICATE_LIMIT" do
        let!(:user3) { FactoryBot.create(:user, email: "someth.i.n.g@g.mail.com", created_at:) }
        let!(:user4) { FactoryBot.create(:user, email: "someth.i.ng@gmail.com", created_at:) }
        it "creates a ban and doesn't notify" do
          expect(User.unscoped.count).to eq 4 # Because the admin from email_domain
          ActionMailer::Base.deliveries = []
          expect(EmailDomain.ban_or_provisional.count).to eq 0
          expect do
            VCR.use_cassette("Email::ConfirmationJob-g.mail") do
              Email::ConfirmationJob.new.perform(user.id)
            end
          end.to change(Notification, :count).by 0
          expect(ActionMailer::Base.deliveries.empty?).to be_truthy
          expect(User.unscoped.count).to eq 4
          expect(EmailDomain.count).to eq 1
          email_domain = EmailDomain.last
          expect(email_domain.ban_blockers).to eq(["below_email_count"])
          expect(email_domain.status).to eq "permitted"
          expect(EmailDomain.ban_or_provisional.count).to eq 0
          expect(EmailBan.count).to eq 1
          expect(user.reload.email_banned?).to be_truthy
          expect(user.email_bans.first).to have_attributes(reason: "email_duplicate")
        end
      end
    end
  end

  # context "with an email with +" do
  #   let(:created_at) { Time.current - 12.hours }
  #   let!(:user_prior) { FactoryBot.create(:user, email: "some@g.mail.com") }
  #   let!(:user) { FactoryBot.create(:user, email: "some+thing@g.mail.com", created_at:) }

  #   it "creates a ban and doesn't notify" do
  #     expect(User.unscoped.count).to eq 2 # Because the admin from email_domain
  #     ActionMailer::Base.deliveries = []
  #     expect do
  #       Email::ConfirmationJob.new.perform(user.id)
  #     end.to change(Notification, :count).by 0
  #     expect(ActionMailer::Base.deliveries.empty?).to be_truthy
  #     expect(User.unscoped.count).to eq 2
  #     expect(EmailBan.count).to eq 1
  #     expect(user.reload.email_banned?).to be_truthy
  #     expect(user.email_bans.first).to have_attributes(reason: "email_duplicate")
  #   end
  #   context "with bikeindex.org domain" do
  #     let!(:user_prior) { FactoryBot.create(:user, email: "some+thing@bikeindex.org", created_at:) }
  #     let(:created_at) { Time.current - 12.hours }
  #     let!(:user) { FactoryBot.create(:user, email: "some@bikeindex.org") }
  #     it "creates" do
  #       expect(User.unscoped.count).to eq 2
  #       expect do
  #         Email::ConfirmationJob.new.perform(user.id)
  #       end.to change(Notification, :count).by 1
  #       expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  #     end
  #   end

  #   context "before period" do
  #     let(:created_at) { Time.current - 14.days }
  #     it "creates the user and sends the email" do
  #       expect(User.unscoped.count).to eq 2
  #       expect do
  #         Email::ConfirmationJob.new.perform(user.id)
  #       end.to change(Notification, :count).by 1
  #       expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  #     end

  #     context "with > PRE_PERIOD_DUPLICATE_LIMIT" do
  #       let!(:user3) { FactoryBot.create(:user, email: "some+ggg@g.mail.com", created_at:) }
  #       # Using period and +
  #       let!(:user4) { FactoryBot.create(:user, email: "som.e+i@gmail.com", created_at:) }
  #       it "creates a ban and doesn't notify" do
  #         expect(User.unscoped.count).to eq 4 # Because the admin from email_domain
  #         ActionMailer::Base.deliveries = []
  #         expect do
  #           Email::ConfirmationJob.new.perform(user.id)
  #         end.to change(Notification, :count).by 0
  #         expect(ActionMailer::Base.deliveries.empty?).to be_truthy
  #         expect(User.unscoped.count).to eq 4
  #         expect(EmailBan.count).to eq 1
  #         expect(user.reload.email_banned?).to be_truthy
  #         expect(user.email_bans.first).to have_attributes(reason: "email_duplicate")
  #       end
  #     end
  #   end
  # end

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
        Email::ConfirmationJob.new.perform(user2.id)
      }.to change(User, :count).by(-1)
      expect(ActionMailer::Base.deliveries.empty?).to be_truthy
    end
    context "calling other user" do
      it "does not delete the other user" do
        expect(user1.id).to be < user2.id
        ActionMailer::Base.deliveries = []
        expect {
          Email::ConfirmationJob.new.perform(user1.id)
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
          Email::ConfirmationJob.new.perform(user.id)
        }.to change(Notification, :count).by(0)
        expect(ActionMailer::Base.deliveries.empty?).to be_truthy
      end
      context "sent 1:10 seconds ago" do
        let(:created_at) { Time.current - 70.seconds }
        it "resends" do
          ActionMailer::Base.deliveries = []
          expect {
            Email::ConfirmationJob.new.perform(user.id)
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
            Email::ConfirmationJob.new.perform(user.id)
          }.to change(Notification, :count).by(0)
          expect(ActionMailer::Base.deliveries.empty?).to be_falsey
          notification.reload
          expect(notification.delivery_success?).to be_truthy
        end
      end
    end
  end
end
