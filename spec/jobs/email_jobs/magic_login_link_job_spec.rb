require "rails_helper"

RSpec.describe EmailJobs::MagicLoginLinkJob, type: :job do
  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:user_email) { user.user_emails.friendly_find(user.email) }
  let(:notification) { Notification.order(:id).last }

  before { ActionMailer::Base.deliveries = [] }

  context "with magic_link_token" do
    before { user.update_auth_token("magic_link_token") }

    it "sends an email and doesn't send again for the same token" do
      token = user.magic_link_token
      expect { described_class.new.perform(user.id) }.to change(Notification, :count).by 1
      expect(ActionMailer::Base.deliveries.count).to eq 1
      expect(user.reload.magic_link_token).to eq token
      expect(notification).to have_attributes(user_id: user.id, kind: "magic_login_link",
        delivery_status: "delivery_success", message_channel_target: user.email)
      expect(user_email.reload.last_email_errored?).to be_falsey

      expect { described_class.new.perform(user.id) }.to change(Notification, :count).by 0
      expect(ActionMailer::Base.deliveries.count).to eq 1
    end

    context "user previously errored" do
      before { user_email.update(last_email_errored: true) }

      it "clears last_email_errored on success" do
        described_class.new.perform(user.id)
        expect(user_email.reload.last_email_errored?).to be_falsey
      end
    end

    context "email_banned user" do
      let!(:email_ban) { FactoryBot.create(:email_ban, user:, reason: :email_duplicate) }

      it "sends an email, so the ban doesn't lock the user out of their account" do
        expect(user.email_banned?).to be_truthy
        expect { described_class.new.perform(user.id) }.to change(Notification, :count).by 1
        expect(ActionMailer::Base.deliveries.count).to eq 1
        expect(notification.delivery_status).to eq "delivery_success"
      end
    end

    context "with InactiveRecipientError" do
      let(:inactive_recipient_error) do
        Postmark::ApiInputError.build("error", {"ErrorCode" => 406, "Message" => "inactive"})
      end
      before { allow(CustomerMailer).to receive(:magic_login_link_email).and_raise(inactive_recipient_error) }

      it "swallows the error and marks user_email errored" do
        expect(user_email.reload.last_email_errored?).to be_falsey
        expect { described_class.new.perform(user.id) }.not_to raise_error
        expect(user_email.reload.last_email_errored?).to be_truthy
        expect(notification).to have_attributes(delivery_status: "delivery_failure",
          delivery_error: "Postmark::InactiveRecipientError")
      end
    end

    context "with unknown postmark error" do
      let(:other_error) { Postmark::ApiInputError.build("error", {"ErrorCode" => 499}) }
      before { allow(CustomerMailer).to receive(:magic_login_link_email).and_raise(other_error) }

      it "re-raises and marks user_email errored" do
        expect { described_class.new.perform(user.id) }.to raise_error(Postmark::ApiInputError)
        expect(user_email.reload.last_email_errored?).to be_truthy
        expect(notification.delivery_status).to eq "delivery_failure"
      end
    end
  end

  context "user doesn't have token" do
    let(:user) { FactoryBot.create(:user) }

    it "throws an error" do
      expect(user.magic_link_token).to be_blank
      expect {
        described_class.new.perform(user.id)
      }.to raise_error(/#{user.id}.*magic_link_token/)
      expect(user.reload.magic_link_token).to be_blank
      expect(ActionMailer::Base.deliveries.empty?).to be_truthy
      expect(Notification.count).to eq 0
    end
  end
end
