require "rails_helper"

RSpec.describe Email::MagicLoginLinkJob, type: :job do
  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:user_email) { user.user_emails.friendly_find(user.email) }

  context "with magic_link_token" do
    before { user.update_auth_token("magic_link_token") }

    it "sends an email" do
      token = user.magic_link_token
      ActionMailer::Base.deliveries = []
      described_class.new.perform(user.id)
      expect(ActionMailer::Base.deliveries.empty?).to be_falsey
      expect(user.reload.magic_link_token).to eq token
      expect(user_email.reload.last_email_errored?).to be_falsey
    end

    context "user previously errored" do
      before { user_email.update(last_email_errored: true) }

      it "clears last_email_errored on success" do
        described_class.new.perform(user.id)
        expect(user_email.reload.last_email_errored?).to be_falsey
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
      end
    end

    context "with unknown postmark error" do
      let(:other_error) { Postmark::ApiInputError.build("error", {"ErrorCode" => 499}) }
      before { allow(CustomerMailer).to receive(:magic_login_link_email).and_raise(other_error) }

      it "re-raises and marks user_email errored" do
        expect { described_class.new.perform(user.id) }.to raise_error(Postmark::ApiInputError)
        expect(user_email.reload.last_email_errored?).to be_truthy
      end
    end
  end

  context "user doesn't have token" do
    let(:user) { FactoryBot.create(:user) }

    it "throws an error" do
      expect(user.magic_link_token).to be_blank
      ActionMailer::Base.deliveries = []
      expect {
        described_class.new.perform(user.id)
      }.to raise_error(/#{user.id}.*magic_link_token/)
      expect(user.reload.magic_link_token).to be_blank
      expect(ActionMailer::Base.deliveries.empty?).to be_truthy
    end
  end
end
