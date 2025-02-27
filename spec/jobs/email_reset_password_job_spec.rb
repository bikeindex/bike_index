require "rails_helper"

RSpec.describe EmailResetPasswordJob, type: :job do
  let(:user) { FactoryBot.create(:user) }
  it "sends a password_reset email" do
    user.update_auth_token("token_for_password_reset")
    token = user.token_for_password_reset
    ActionMailer::Base.deliveries = []
    expect(Notification.count).to eq 0
    EmailResetPasswordJob.new.perform(user.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
    user.reload
    expect(user.token_for_password_reset).to eq token
    expect(Notification.count).to eq 1
    expect(Notification.last).to have_attributes(message_channel: "email", kind: "password_reset",
      delivery_status: "delivery_success", message_channel_target: user.email)
    # It doesn't send again
    expect do
      EmailResetPasswordJob.new.perform(user.id)
    end.to change(Notification, :count).by 0
    expect(ActionMailer::Base.deliveries.count).to eq 1
  end
  context "user doesn't have token" do
    it "raises an error" do
      user.save
      expect(user.token_for_password_reset).to be_blank
      ActionMailer::Base.deliveries = []
      expect(Notification.count).to eq 0
      expect {
        described_class.new.perform(user.id)
      }.to raise_error(/#{user.id}.*token_for_password_reset/)
      user.reload
      expect(user.magic_link_token).to be_blank
      expect(ActionMailer::Base.deliveries.empty?).to be_truthy
      expect(Notification.count).to eq 0
    end
  end
  context "with a notification created before token time" do
    let!(:notification) do
      FactoryBot.create(:notification, user:, kind: described_class::NOTIFICATION_KIND,
        created_at: Time.current - 10.seconds)
    end
    it "creates a new notification" do
      user.update_auth_token("token_for_password_reset")
      ActionMailer::Base.deliveries = []
      expect do
        EmailResetPasswordJob.new.perform(user.id)
      end.to change(Notification, :count).by 1
      expect(ActionMailer::Base.deliveries.empty?).to be_falsey
      expect(Notification.last).to have_attributes(message_channel: "email", kind: "password_reset",
        delivery_status: "delivery_success", message_channel_target: user.email)
    end
  end
end
