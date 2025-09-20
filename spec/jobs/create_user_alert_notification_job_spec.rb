require "rails_helper"

RSpec.describe CreateUserAlertNotificationJob, type: :job do
  let(:instance) { described_class.new }
  include_context :scheduled_job
  include_examples :scheduled_job_tests

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
        expect(notification.delivery_success?).to be_truthy
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

    context "theft_alert_without_photo" do
      let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, latitude: nil, longitude: nil) }
      let!(:theft_alert) { FactoryBot.create(:theft_alert_paid, user: bike.user, stolen_record: bike.current_stolen_record) }
      let!(:user_alert) { FactoryBot.create(:user_alert, user: bike.user, bike: bike, kind: "theft_alert_without_photo") }
      let!(:user_alert2) { FactoryBot.create(:user_alert, user: bike.user, bike: bike, kind: "stolen_bike_without_location") }
      it "creates and sends notifications" do
        expect(bike.current_stolen_record).to be_present
        expect(theft_alert.reload.missing_photo?).to be_truthy
        expect(theft_alert.missing_location?).to be_truthy
        expect(user_alert.reload.create_notification?).to be_truthy
        expect(bike.reload.user.email).to eq bike.owner_email
        expect(UserAlert.where(bike_id: bike.id, user_id: bike.user_id).pluck(:id)).to match_array([user_alert.id, user_alert2.id])
        expect(user_alert.create_notification?).to be_truthy
        expect(user_alert2.create_notification?).to be_falsey

        ActionMailer::Base.deliveries = []
        expect {
          instance.perform(user_alert.id)
          instance.perform(user_alert2.id)
        }.to change(Notification, :count).by 1 # NOTE: Doesn't create an alert for both missing location and photo
        notification = Notification.last
        expect(user_alert.reload.notification&.id).to eq notification.id
        expect(notification.delivery_success?).to be_truthy
        expect(notification.notifiable_id).to eq user_alert.id

        expect(ActionMailer::Base.deliveries.count).to eq 1
        mail = ActionMailer::Base.deliveries.last
        expect(mail.to).to eq([bike.owner_email])
        expect(mail.subject).to eq "Your stolen bike needs a photo"
        expect(mail.body.encoded).to match(/promoted.alert/i)
      end
    end
  end
end
