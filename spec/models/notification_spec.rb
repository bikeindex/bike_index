require "rails_helper"

RSpec.describe Notification, type: :model do
  describe "send_notification" do
    it "doesn't send for confirmation_email" do
      expect do
        FactoryBot.create(:notification, kind: "confirmation_email")
      end.to_not change(SendNotificationWorker.jobs, :count)
    end
    context "view_claimed_ticket" do
      let(:ticket) { FactoryBot.create(:ticket_claimed) }
      let(:notification) { FactoryBot.build(:notification, kind: "view_claimed_ticket", appointment: ticket.appointment, user: nil) }
      it "sends only on creation" do
        Sidekiq::Worker.clear_all
        expect do
          notification.save
        end.to change(SendNotificationWorker.jobs, :count).by 1
        expect(SendNotificationWorker.jobs.map { |j| j["args"] }.flatten).to eq([notification.id])
        expect do
          notification.update(updated_at: Time.current)
          notification.destroy
        end.to_not change(SendNotificationWorker.jobs, :count)
      end
    end
  end
end
