require "rails_helper"

RSpec.describe Backfills::LastEmailErroredEmailBanJob, type: :job do
  describe "perform" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    let!(:primary_email) { UserEmail.create_confirmed_primary_email(user) }
    let!(:errored_email) { FactoryBot.create(:user_email, user:, last_email_errored: true) }
    let!(:delivered_email) { FactoryBot.create(:user_email, user:) }

    it "creates a delivery_failure ban for the errored email" do
      expect do
        Sidekiq::Testing.inline! { described_class.perform_async }
      end.to change(EmailBan, :count).by 1

      email_ban = EmailBan.last
      expect(email_ban.reason).to eq "delivery_failure"
      expect(email_ban.user_id).to eq user.id
      expect(email_ban.user_email_id).to eq errored_email.id
      expect(EmailBan.ban?(user, user_email: errored_email)).to be_truthy
      expect(EmailBan.ban?(user, user_email: delivered_email)).to be_falsey

      # It doesn't double up on a re-run
      expect do
        Sidekiq::Testing.inline! { described_class.perform_async }
      end.to change(EmailBan, :count).by 0
    end

    context "user with a single email" do
      let(:user) { FactoryBot.create(:user) } # unconfirmed, so there is no primary user_email
      let!(:primary_email) { nil }
      let!(:delivered_email) { nil }

      it "bans the user rather than the address" do
        expect(user.reload.user_emails.pluck(:id)).to eq([errored_email.id])

        Sidekiq::Testing.inline! { described_class.perform_async }

        expect(EmailBan.last.user_email_id).to be_nil
        expect(EmailBan.ban?(user)).to be_truthy
      end
    end
  end
end
