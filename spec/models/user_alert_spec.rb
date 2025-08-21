# == Schema Information
#
# Table name: user_alerts
#
#  id              :bigint           not null, primary key
#  dismissed_at    :datetime
#  kind            :integer
#  message         :text
#  resolved_at     :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  bike_id         :bigint
#  organization_id :bigint
#  theft_alert_id  :bigint
#  user_id         :bigint
#  user_phone_id   :bigint
#
# Indexes
#
#  index_user_alerts_on_bike_id          (bike_id)
#  index_user_alerts_on_organization_id  (organization_id)
#  index_user_alerts_on_theft_alert_id   (theft_alert_id)
#  index_user_alerts_on_user_id          (user_id)
#  index_user_alerts_on_user_phone_id    (user_phone_id)
#
require "rails_helper"

RSpec.describe UserAlert, type: :model do
  describe "factory" do
    let(:user_alert) { FactoryBot.create(:user_alert) }
    it "is valid" do
      expect(user_alert).to be_valid
    end
    context "stolen_bike_without_location" do
      let(:user_alert) { FactoryBot.create(:user_alert_stolen_bike_without_location) }
      it "is valid" do
        expect(user_alert).to be_valid
        bike = user_alert.reload.bike
        expect(bike.current_stolen_record&.id).to be_present
        expect(bike.current_stolen_record&.without_location?).to be_truthy
        # Running the process doesn't create a new alert
        expect {
          expect(UserAlert.update_stolen_bike_without_location(user: user_alert.user, bike: user_alert.bike)).to be_truthy
        }.to_not change(UserAlert, :count)
      end
    end
  end

  describe "update_phone_waiting_confirmation" do
    let(:user) { FactoryBot.create(:user) }
    let(:user_phone) { FactoryBot.create(:user_phone, user: user) }
    it "creates only once" do
      expect {
        UserAlert.update_phone_waiting_confirmation(user: user, user_phone: user_phone)
      }.to change(UserAlert, :count).by 1
      user_alert = UserAlert.last
      expect(user_alert).to be_valid
      expect(user_alert.active?).to be_truthy
      expect(user_alert.kind).to eq "phone_waiting_confirmation"
      expect(user_alert.placement).to eq "general"
      expect(user_alert.general?).to be_truthy
      expect(user_alert.account?).to be_falsey
      expect(user_alert.active?).to be_truthy
      expect(user_alert.inactive?).to be_falsey
      # It doesn't create a second time
      expect {
        UserAlert.update_phone_waiting_confirmation(user: user, user_phone: user_phone)
      }.to_not change(UserAlert, :count)
      expect(user.user_alerts.pluck(:id)).to eq([user_alert.id])
      # Dismissing
      user_alert.dismiss!
      expect(user_alert.dismissed_at).to be_within(1).of Time.current
      expect(user_alert.dismissed?).to be_truthy
      expect(user_alert.active?).to be_falsey
      expect(user_alert.inactive?).to be_truthy
      expect(user_alert.resolved?).to be_falsey
    end
  end

  describe "create_notification?" do
    it "notification has the kinds" do
      kinds = UserAlert.notification_kinds.map { |k| "user_alert_#{k}" }
      expect((Notification.kinds & kinds).count).to eq UserAlert.notification_kinds.count
    end
    context "stolen bike without location" do
      let(:user_alert) { FactoryBot.create(:user_alert_stolen_bike_without_location) }
      let(:bike_updated_at) { Time.current - 2.hours }
      before do
        user_alert.update_column :updated_at, Time.current - 2.hours
        user_alert&.bike&.update_column :updated_at, bike_updated_at
      end
      it "is truthy if not updated" do
        expect(user_alert.reload.updated_at).to be < Time.current - 119.minutes
        expect(user_alert.create_notification?).to be_truthy
        expect(UserAlert.create_notification.pluck(:id)).to eq([user_alert.id])
        user_alert.update(updated_at: Time.current)
        expect(user_alert.create_notification?).to be_falsey
        expect(UserAlert.create_notification.pluck(:id)).to eq([])
      end
      context "bike updated after" do
        let(:bike_updated_at) { Time.current - 50.minutes }
        it "is false" do
          expect(user_alert.reload.create_notification?).to be_falsey
        end
      end
      context "bike updated before" do
        let(:bike_updated_at) { Time.current - 1.month }
        it "is false" do
          expect(user_alert.reload.create_notification?).to be_falsey
        end
      end
      context "resolved" do
        it "is false" do
          user_alert.resolve!
          expect(user_alert.reload.create_notification?).to be_falsey
          expect(UserAlert.create_notification.pluck(:id)).to eq([])
        end
      end
      context "with another user_alert" do
        let(:user_alert2) { FactoryBot.create(:user_alert, user: user_alert.user, bike: user_alert.bike, kind: "theft_alert_without_photo") }
        let!(:notification) { FactoryBot.create(:notification, notifiable: user_alert2, kind: "user_alert_theft_alert_without_photo") }
        it "is false" do
          expect(user_alert2.reload.notification.present?).to be_truthy
          expect(user_alert2.create_notification?).to be_falsey
          expect(user_alert.reload.create_notification?).to be_falsey
        end
      end
      context "with notification" do
        let(:notification) { FactoryBot.create(:notification) }
        it "is false" do
          user_alert.update(notification: notification)
          expect(user_alert.reload.create_notification?).to be_falsey
          expect(UserAlert.create_notification.pluck(:id)).to eq([])
        end
      end
      context "stolen bike no_notify" do
        it "is false" do
          user_alert.bike.current_stolen_record.update(receive_notifications: false)
          expect(user_alert.reload.create_notification?).to be_falsey
        end
      end
    end
  end
end
