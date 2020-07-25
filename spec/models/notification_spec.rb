require "rails_helper"

RSpec.describe Notification, type: :model do
  describe "send_notification" do
    it "doesn't send for confirmation_email" do
      expect {
        FactoryBot.create(:notification, kind: "confirmation_email")
      }.to_not change(SendNotificationWorker.jobs, :count)
    end
    context "view_appointment" do
      let(:ticket) { FactoryBot.create(:appointment) }
      let(:notification) { FactoryBot.build(:notification, kind: "view_appointment", appointment: appointment, user: nil) }
      it "sends only on creation" do
        Sidekiq::Worker.clear_all
        expect {
          notification.save
        }.to change(SendNotificationWorker.jobs, :count).by 1
        expect(SendNotificationWorker.jobs.map { |j| j["args"] }.flatten).to eq([notification.id])
        expect {
          notification.update(updated_at: Time.current)
          notification.destroy
        }.to_not change(SendNotificationWorker.jobs, :count)
      end
    end
  end
end
