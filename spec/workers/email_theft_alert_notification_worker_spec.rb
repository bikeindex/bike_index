require "rails_helper"

RSpec.describe EmailTheftAlertNotificationWorker, type: :job do
  describe ".perform" do
    it "sends email to admins" do
      theft_alert = FactoryBot.create(:theft_alert_paid)

      expect { described_class.new.perform(theft_alert.id) }
        .to(change { ActionMailer::Base.deliveries.length }.by(1))
    end
  end
end
