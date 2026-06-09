require "rails_helper"

RSpec.describe Backfills::ParkingNotificationNotificationJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let(:parking_notification) { FactoryBot.create(:parking_notification) }

    it "creates a delivery_success notification for email_success without sending email" do
      parking_notification.update_column(:delivery_status, "email_success")
      ActionMailer::Base.deliveries = []
      expect {
        instance.perform(parking_notification.id)
      }.to change { parking_notification.notifications.count }.by(1)
      expect(ActionMailer::Base.deliveries.count).to eq 0

      notification = parking_notification.notifications.first
      expect(notification.kind).to eq "parking_notification"
      expect(notification.delivery_status).to eq "delivery_success"
      expect(notification.delivery_error).to be_nil
      expect(notification.message_channel_target).to eq parking_notification.email
      expect(notification.bike_id).to eq parking_notification.bike_id
      expect(parking_notification.reload.email_success?).to be_truthy
    end

    it "creates a delivery_failure notification when delivery_status is not email_success" do
      expect(parking_notification.delivery_status).to be_blank
      expect {
        instance.perform(parking_notification.id)
      }.to change { parking_notification.notifications.count }.by(1)

      notification = parking_notification.notifications.first
      expect(notification.delivery_status).to eq "delivery_failure"
      expect(notification.delivery_error).to eq "Failed pre-notification tracking"
      expect(parking_notification.reload.email_success?).to be_falsey
    end

    it "is idempotent" do
      instance.perform(parking_notification.id)
      expect { instance.perform(parking_notification.id) }
        .not_to change { Notification.count }
    end

    context "when send_email? is false" do
      let(:parking_notification) { FactoryBot.create(:parking_notification_unregistered) }
      it "does not create a notification" do
        expect(parking_notification.send_email?).to be_falsey
        expect { instance.perform(parking_notification.id) }
          .not_to change { Notification.count }
      end
    end
  end

  describe "enqueue_workers" do
    let!(:registered) { FactoryBot.create(:parking_notification) }
    let!(:unregistered) { FactoryBot.create(:parking_notification_unregistered) }

    it "enqueues only the emailable records" do
      expect {
        instance.perform
      }.to change(described_class.jobs, :size).by(1)
      expect(described_class.jobs.map { |j| j["args"] }).to eq([[registered.id]])
    end
  end
end
