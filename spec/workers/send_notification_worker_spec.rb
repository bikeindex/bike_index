require "rails_helper"

RSpec.describe SendNotificationWorker, type: :job do
  let(:instance) { described_class.new }
  before { ActionMailer::Base.deliveries = [] }

  context "view_appointment" do
    let(:ticket) { FactoryBot.create(:appointment) }
    let(:notification) { FactoryBot.create(:notification, kind: "view_appointment", appointment: appointment, user: nil) }
    it "sends an email" do
      expect(notification.email_success?).to be_falsey
      expect {
        instance.perform(notification.id)
      }.to change(ActionMailer::Base.deliveries, :count).by 1
      notification.reload
      expect(notification.email_success?).to be_truthy
    end
  end

  context "confirmation_email" do
    let(:notification) { FactoryBot.create(:notification, kind: "confirmation_email") }
    it "doesn't send, doesn't update" do
      expect(notification.email_success?).to be_falsey
      instance.perform(notification.id)
      expect {
        instance.perform(notification.id)
      }.to_not change(ActionMailer::Base.deliveries, :count)
      notification.reload
      expect(notification.email_success?).to be_falsey
    end
  end
end
