require "rails_helper"

RSpec.describe UserPhoneConfirmationJob, type: :job do
  let(:instance) { described_class.new }
  let(:user) { FactoryBot.create(:user) }
  let(:user_phone) { FactoryBot.create(:user_phone, user: user, phone: "2134442323") }
  before { stub_const("UserPhoneConfirmationJob::UPDATE_TWILIO", true) }
  it "adds the phone for the user" do
    expect(user_phone.confirmed?).to be_falsey
    expect(user_phone.notifications.count).to eq 0
    user.reload
    expect(user.phone_waiting_confirmation?).to be_truthy
    expect(user.alert_slugs).to eq([])
    instance.perform(user_phone.id)
    user_phone.reload
    expect(user_phone.confirmed?).to be_falsey
    expect(user_phone.notifications.count).to eq 0
    expect(user.alert_slugs).to eq([])
  end
  context "with phone_verification enabled" do
    before { Flipper.enable(:phone_verification) }
    it "adds the phone for the user" do
      expect(user_phone.confirmed?).to be_falsey
      expect(user_phone.notifications.count).to eq 0
      user.reload
      expect(user.phone_waiting_confirmation?).to be_truthy
      expect(user.alert_slugs).to eq([])
      VCR.use_cassette("user_phone_confirmation_worker", match_requests_on: [:path]) do
        instance.perform(user_phone.id)
      end
      user_phone.reload
      expect(user_phone.confirmed?).to be_falsey
      expect(user_phone.notifications.count).to eq 1

      notification = user_phone.notifications.first
      expect(notification.user_id).to eq user.id
      expect(notification.notifiable).to eq user_phone
      expect(notification.kind).to eq "phone_verification"

      user.reload
      expect(user.phone_waiting_confirmation?).to be_truthy

      expect(user.alert_slugs).to eq(["phone_waiting_confirmation"])
    end
  end
end
