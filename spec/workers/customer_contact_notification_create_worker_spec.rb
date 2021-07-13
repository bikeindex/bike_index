require "rails_helper"

RSpec.describe CustomerContactNotificationCreateWorker, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let(:customer_contact) { FactoryBot.build(:customer_contact) }
    it "It enqueues on create" do
      expect {
        customer_contact.save
      }.to change(CustomerContactNotificationCreateWorker.jobs, :count).by 1
      expect {
        instance.perform(customer_contact.id)
        instance.perform(customer_contact.id)
        instance.perform(customer_contact.id)
      }.to change(Notification, :count).by 1
      customer_contact.reload
      notification = customer_contact.notification
      expect(notification.user_id).to be_blank
      expect(notification.kind).to eq customer_contact.kind
      expect(notification.delivered?).to be_truthy
      expect(notification.bike_id).to eq customer_contact.bike_id
      expect(notification.calculated_email).to eq customer_contact.user_email
      expect(notification.sender).to eq customer_contact.creator
      expect(notification.sender_display_name).to eq customer_contact.creator.display_name
    end
  end
end
