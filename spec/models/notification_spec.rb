require "rails_helper"

RSpec.describe Notification, type: :model do
  describe "notifiable_display_name" do
    let(:notification) { FactoryBot.create(:notification) }
    it "is blank" do
      expect(notification.notifiable_display_name).to be_blank
    end
    context "donation" do
      let(:payment) { FactoryBot.create(:payment) }
      let(:notification) { FactoryBot.create(:notification, kind: "donation_stolen", notifiable: payment, user: payment.user) }
      it "is payment" do
        expect(notification.notifiable_display_name).to eq "Payment ##{payment.id}"
      end
    end
  end
end
