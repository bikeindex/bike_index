require "rails_helper"

RSpec.describe Email::AdditionalEmailConfirmationJob, type: :job do
  let(:user_email) { FactoryBot.create(:user_email, confirmation_token: "xxxx") }

  it "sends a confirm your additional email, email" do
    ActionMailer::Base.deliveries = []
    expect { described_class.new.perform(user_email.id) }.to change(Notification, :count).by 1

    expect(ActionMailer::Base.deliveries.count).to eq 1
    notification = Notification.last
    expect(notification.kind).to eq "additional_email_confirmation"
    expect(notification.notifiable_id).to eq user_email.id
    expect(notification.user_id).to eq user_email.user_id
    expect(notification.message_channel_target).to eq user_email.email
    expect(notification.delivery_status).to eq "delivery_success"

    # It doesn't send again immediately
    expect { described_class.new.perform(user_email.id) }.to change(Notification, :count).by 0
    expect(ActionMailer::Base.deliveries.count).to eq 1
  end

  context "with InactiveRecipientError" do
    let(:inactive_recipient_error) do
      Postmark::ApiInputError.build("error", {"ErrorCode" => 406, "Message" => "inactive"})
    end
    before { allow(CustomerMailer).to receive(:additional_email_confirmation).and_raise(inactive_recipient_error) }

    it "swallows the error and marks user_email errored" do
      expect { described_class.new.perform(user_email.id) }.to change(Notification, :count).by 1

      notification = Notification.last
      expect(notification.delivery_status).to eq "delivery_failure"
      expect(notification.delivery_error).to eq "Postmark::InactiveRecipientError"
      expect(user_email.reload.last_email_errored).to be_truthy
    end
  end
end
