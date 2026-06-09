require "rails_helper"

RSpec.describe Backfills::ParkingNotificationNotificationJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let(:parking_notification) { FactoryBot.create(:parking_notification) }

    context "with delivery_status email_success" do
      before { parking_notification.update_column(:delivery_status, "email_success") }

      it "creates a delivery_success notification without sending email" do
        ActionMailer::Base.deliveries = []
        expect {
          instance.perform(parking_notification.id)
        }.to change { parking_notification.notifications.count }.by(1)
        expect(ActionMailer::Base.deliveries.count).to eq 0

        notification = parking_notification.notifications.first
        expect(notification.kind).to eq "parking_notification"
        expect(notification.delivery_status).to eq "delivery_success"
        expect(notification.message_channel_target).to eq parking_notification.email
        expect(notification.bike_id).to eq parking_notification.bike_id
        expect(parking_notification.reload.email_success?).to be_truthy
      end

      it "is idempotent" do
        instance.perform(parking_notification.id)
        expect { instance.perform(parking_notification.id) }
          .not_to change { Notification.count }
      end
    end

    context "with delivery_status nil or bike_unregistered" do
      it "does not create a notification" do
        expect { instance.perform(parking_notification.id) }
          .not_to change { Notification.count }
        parking_notification.update_column(:delivery_status, "bike_unregistered")
        expect { instance.perform(parking_notification.id) }
          .not_to change { Notification.count }
      end
    end
  end

  describe "enqueue_workers" do
    let!(:sent) do
      pn = FactoryBot.create(:parking_notification)
      pn.update_column(:delivery_status, "email_success")
      pn
    end
    let!(:unsent) { FactoryBot.create(:parking_notification) }

    it "enqueues only the email_success records" do
      expect {
        instance.perform
      }.to change(described_class.jobs, :size).by(1)
      expect(described_class.jobs.map { |j| j["args"] }).to eq([[sent.id]])
    end
  end
end
