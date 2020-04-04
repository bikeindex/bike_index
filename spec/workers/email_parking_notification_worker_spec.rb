require "rails_helper"

RSpec.describe EmailParkingNotificationWorker, type: :job do
  let(:subject) { described_class }
  let(:instance) { subject.new }
  before { ActionMailer::Base.deliveries = [] }

  context "delivery failed" do
    let(:parking_notification) { FactoryBot.create(:parking_notification, delivery_status: "failure") }
    it "does not send" do
      instance.perform(parking_notification.id)
      expect(ActionMailer::Base.deliveries.empty?).to be_truthy
    end
  end

  context "delivery succeeded" do
    let(:parking_notification) { FactoryBot.create(:parking_notification, delivery_status: "success") }
    it "does not send" do
      instance.perform(parking_notification.id)
      expect(ActionMailer::Base.deliveries.empty?).to be_truthy
    end
  end

  context "delivery_status nil" do
    let(:parking_notification) { FactoryBot.create(:parking_notification, delivery_status: nil) }
    it "sends an email" do
      instance.perform(parking_notification.id)
      expect(ActionMailer::Base.deliveries.empty?).to be_falsey
      parking_notification.reload
      expect(parking_notification.delivery_status).to be_present
    end
  end
end
