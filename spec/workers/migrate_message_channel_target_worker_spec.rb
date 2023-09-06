require "rails_helper"

RSpec.describe MigrateMessageChannelTargetWorker, type: :job do
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  describe "perform" do
    let(:user) { FactoryBot.create(:user, email: "wat@example.com")}
    let(:notification) { FactoryBot.create(:notification, user: user) }
    it "schedules all the workers" do
      notification.update_column :delivery_status, "email_success"
      expect(notification.reload.message_channel_target).to be_nil
      described_class.new.perform(notification.id)
      expect(notification.reload.message_channel_target).to eq "wat@example.com"
    end
  end
end
