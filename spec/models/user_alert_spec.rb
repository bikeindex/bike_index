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
        expect(bike.current_stolen_record&.without_street?).to be_truthy
        # Running the process doesn't create a new alert
        expect {
          expect(UserAlert.update_stolen_bike_without_location(user: user_alert.user, bike: user_alert.bike)).to be_truthy
        }.to_not change(UserAlert, :count)
      end
    end
  end

  describe "uniq_kinds" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    let(:user_phone) { FactoryBot.create(:user_phone, user:) }
    let(:theft_alert) { FactoryBot.create(:theft_alert) }

    it "validates uniqueness of alertable only for uniq_kinds" do
      FactoryBot.create(:user_alert, user:, kind: "phone_waiting_confirmation", alertable: user_phone)
      duplicate = FactoryBot.build(:user_alert, user:, kind: "phone_waiting_confirmation", alertable: user_phone)
      expect(duplicate).to_not be_valid
      expect(duplicate.errors.attribute_names).to eq([:alertable_id])

      # theft_alert_without_photo isn't a uniq_kind - prod has duplicates that must stay saveable
      FactoryBot.create(:user_alert, user:, kind: "theft_alert_without_photo", alertable: theft_alert)
      expect(FactoryBot.build(:user_alert, user:, kind: "theft_alert_without_photo", alertable: theft_alert)).to be_valid
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
      expect(user_alert.alertable).to eq user_phone
      expect(user_alert.alertable_type).to eq "UserPhone"
    end

    context "another user has an alert for the same phone" do
      let!(:user_alert) do
        FactoryBot.create(:user_alert, user:, kind: "phone_waiting_confirmation", alertable: user_phone)
      end
      let(:other_alert) do
        FactoryBot.create(:user_alert, kind: "phone_waiting_confirmation", alertable: user_phone)
      end

      it "doesn't match across users" do
        expect(other_alert.user_id).to_not eq user.id

        expect {
          UserAlert.update_phone_waiting_confirmation(user: other_alert.user, user_phone:)
        }.to_not change(UserAlert, :count)
        expect(UserAlert.pluck(:id)).to match_array([user_alert.id, other_alert.id])
      end
    end
  end

  describe "update_theft_alert_without_photo" do
    let(:theft_alert) { FactoryBot.create(:theft_alert) }
    let(:user) { theft_alert.user }

    it "creates only once" do
      expect(theft_alert.missing_photo?).to be_truthy
      expect {
        UserAlert.update_theft_alert_without_photo(user:, theft_alert:)
      }.to change(UserAlert, :count).by 1
      user_alert = UserAlert.last
      expect(user_alert.kind).to eq "theft_alert_without_photo"
      expect(user_alert.alertable).to eq theft_alert
      expect(user_alert.alertable_type).to eq "TheftAlert"
      # It doesn't create a second time
      expect {
        UserAlert.update_theft_alert_without_photo(user:, theft_alert:)
      }.to_not change(UserAlert, :count)
    end

    context "another user has an alert for the same theft_alert" do
      let!(:user_alert) do
        FactoryBot.create(:user_alert, user:, kind: "theft_alert_without_photo", alertable: theft_alert)
      end
      let(:other_alert) do
        FactoryBot.create(:user_alert, kind: "theft_alert_without_photo", alertable: theft_alert)
      end

      it "doesn't match across users" do
        expect(other_alert.user_id).to_not eq user.id

        expect {
          UserAlert.update_theft_alert_without_photo(user: other_alert.user, theft_alert:)
        }.to_not change(UserAlert, :count)
        expect(UserAlert.pluck(:id)).to match_array([user_alert.id, other_alert.id])
      end
    end
  end

  describe "update_unfinished_registrations" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    let!(:b_param) do
      FactoryBot.create(:b_param_unfinished_registration, creator: user)
    end

    it "leaves the alert the b_param created alone" do
      expect {
        UserAlert.update_unfinished_registrations(user)
      }.to_not change(UserAlert, :count)
      expect(user.user_alerts.active.pluck(:kind)).to eq ["unfinished_registration"]
    end

    # Past the token expiration it drops out of BParam.unfinished_registrations, so
    # nothing would resolve the alert if it were the only thing looked at
    context "with the b_param expired" do
      before { b_param.update_column(:created_at, Time.current - BParam::TOKEN_EXPIRATION - 1.day) }

      it "resolves the alert" do
        UserAlert.update_unfinished_registrations(user)

        expect(user.user_alerts.active.pluck(:kind)).to eq []
        expect(UserAlert.refresh_alert_slugs(user)).to be_truthy
        expect(user.reload.alert_slugs).to eq []
      end
    end

    context "with the b_param deleted" do
      before { BParam.where(id: b_param.id).delete_all }

      it "resolves the alert" do
        UserAlert.update_unfinished_registrations(user)

        expect(user.user_alerts.active.pluck(:kind)).to eq []
      end
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
