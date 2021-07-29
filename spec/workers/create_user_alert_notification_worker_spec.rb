require "rails_helper"

RSpec.describe CreateUserAlertNotificationWorker, type: :job do
  let(:instance) { described_class.new }
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  describe "perform" do
    before do
      user_alert.update_column :updated_at, Time.current - 2.hours
      bike&.update_column :updated_at, Time.current - 2.hours
      user_alert.reload
    end

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
      end
    end

    # context "stolen_bike_without_location" do
    #   let!(:user_alert) { FactoryBot.create(:user_alert_stolen_bike_without_location) }
    #   let(:bike) { user_alert.bike }
    #   it "creates and sends notifications" do
    #     expect(user_alert.create_notification?).to be_truthy
    #     ActionMailer::Base.deliveries = []
    #     expect {
    #       instance.perform(user_alert.id)
    #     }.to change(Notification, :count).by 1
    #     notification = Notification.last
    #     expect(user_alert.reload.notification&.id).to eq notification.id
    #     expect(notification.delivered?).to be_truthy
    #     expect(UserAlert.with_notification.pluck(:id)).to eq([user_alert.id])

    #     expect(ActionMailer::Base.deliveries.count).to eq 1
    #     mail = ActionMailer::Base.deliveries.last
    #     expect(mail.to).to eq([customer_contact.user_email])
    #     expect(mail.subject).to eq "Your stolen bike is missing its location"
    #   end
    # end
  end
end
