require "rails_helper"

RSpec.describe CreateStolenGeojsonWorker, type: :job do
  let(:instance) { described_class.new }
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  describe "perform" do
    let!(:bike) { FactoryBot.create(:stolen_bike) }
    context "stolen_bike_without_location" do
      let!(:user_alert) { FactoryBot.create(:user_alert_stolen_bike_without_location) }
      let(:bike) { user_alert.bike }
      it "creates and sends notifications" do
        expect(user_alert.create_notification?).to be_truthy
        ActionMailer::Base.deliveries = []
        expect {
          instance.perform(user_alert.id)
        }.to change(Notification, :count).by 1
        notification = Notification.last
        expect(user_alert.reload.notification&.id).to eq notification.id
        expect(notification.delivered?).to be_truthy
        expect(UserAlert.with_notification.pluck(:id)).to eq([user_alert.id])

        expect(ActionMailer::Base.deliveries.count).to eq 1
        mail = ActionMailer::Base.deliveries.last
        expect(mail.to).to eq([bike.owner_email])
        expect(mail.subject).to eq "Your stolen bike is missing its location"
        expect(mail.body.encoded).to match(/missing.location/i)

        expect { instance.perform(user_alert.id) }.to_not change(Notification, :count)
        expect { instance.perform(user_alert.id) }.to_not change(Notification, :count)
      end
    end
  end
end
