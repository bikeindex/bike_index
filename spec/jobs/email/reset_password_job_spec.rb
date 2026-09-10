require "rails_helper"

RSpec.describe Email::ResetPasswordJob, type: :job do
  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:user_email) { user.user_emails.friendly_find(user.email) }
  let(:notification) { Notification.order(:id).last }

  before { ActionMailer::Base.deliveries = [] }

  context "with token_for_password_reset" do
    before { user.update_auth_token("token_for_password_reset") }

    it "sends an email and doesn't send again for the same token" do
      expect { described_class.new.perform(user.id) }.to change(Notification, :count).by 1
      expect(ActionMailer::Base.deliveries.count).to eq 1
      target_attributes = {user_id: user.id, kind: "password_reset", delivery_status: "delivery_success"}
      expect(notification).to have_attributes(target_attributes)
      expect(user_email.reload.last_email_errored?).to be_falsey

      expect { described_class.new.perform(user.id) }.to change(Notification, :count).by 0
      expect(ActionMailer::Base.deliveries.count).to eq 1
    end

    context "banned user" do
      before { user.update(banned: true) }

      it "doesn't send an email or create a notification" do
        expect { described_class.new.perform(user.id) }.to change(Notification, :count).by 0
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end

    context "email_banned user" do
      let!(:email_ban) { FactoryBot.create(:email_ban, user:, reason: :email_duplicate) }

      it "sends an email, so the ban doesn't lock the user out of their account" do
        expect(user.reload.banned?).to be_falsey
        expect(user.email_banned?).to be_truthy
        expect { described_class.new.perform(user.id) }.to change(Notification, :count).by 1
        expect(ActionMailer::Base.deliveries.count).to eq 1
        target_attributes = {user_id: user.id, kind: "password_reset", delivery_status: "delivery_success"}
        expect(notification).to have_attributes(target_attributes)
      end
    end
  end

  context "without token_for_password_reset" do
    it "raises" do
      expect(user.token_for_password_reset).to be_blank
      expect { described_class.new.perform(user.id) }
        .to raise_error(/#{user.id}.*token_for_password_reset/)
      expect(ActionMailer::Base.deliveries.count).to eq 0
    end
  end
end
