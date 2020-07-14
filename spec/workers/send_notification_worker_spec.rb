require "rails_helper"

RSpec.describe SendNotificationWorker, type: :job do
  let(:instance) { described_class.new }
  before { ActionMailer::Base.deliveries = [] }

  context "view_claimed_ticket" do
    let(:ticket) { FactoryBot.create(:ticket_claimed) }
    let(:notification) { FactoryBot.create(:notification, kind: "view_claimed_ticket", appointment: ticket.appointment, user: nil) }
    it "sends an email" do
      expect(notification.email_success?).to be_falsey
      expect do
        instance.perform(notification.id)
      end.to change(ActionMailer::Base.deliveries, :count).by 1
      notification.reload
      expect(notification.email_success?).to be_truthy
    end
  end

  context "confirmation_email" do
    let(:notification) { FactoryBot.create(:notification, kind: "confirmation_email") }
    it "doesn't send, doesn't update" do
      expect(notification.email_success?).to be_falsey
      instance.perform(notification.id)
      expect do
        instance.perform(notification.id)
      end.to_not change(ActionMailer::Base.deliveries, :count)
      notification.reload
      expect(notification.email_success?).to be_falsey
    end
  end
end
