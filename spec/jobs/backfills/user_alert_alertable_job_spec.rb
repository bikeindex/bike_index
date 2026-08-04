require "rails_helper"

RSpec.describe Backfills::UserAlertAlertableJob, type: :job do
  describe "perform" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    let(:user_phone) { FactoryBot.create(:user_phone, user:) }
    let(:theft_alert) { FactoryBot.create(:theft_alert) }
    let!(:legacy_phone) do
      FactoryBot.create(:user_alert, user:, kind: "phone_waiting_confirmation", user_phone:)
    end
    let!(:legacy_theft_alert) do
      FactoryBot.create(:user_alert, user:, kind: "theft_alert_without_photo", theft_alert:)
    end
    let!(:bike_alert) { FactoryBot.create(:user_alert_stolen_bike_without_location) }

    it "copies the legacy columns into alertable" do
      expect(legacy_phone.alertable_id).to be_blank
      expect(legacy_theft_alert.alertable_id).to be_blank

      Sidekiq::Testing.inline! { described_class.perform_async }

      expect(legacy_phone.reload.alertable).to eq user_phone
      expect(legacy_phone.alertable_type).to eq "UserPhone"
      expect(legacy_theft_alert.reload.alertable).to eq theft_alert
      expect(legacy_theft_alert.alertable_type).to eq "TheftAlert"
      # bike_id isn't part of alertable
      expect(bike_alert.reload.alertable_id).to be_blank
    end
  end
end
