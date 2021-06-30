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
end
