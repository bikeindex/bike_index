require "rails_helper"

RSpec.describe UserPhoneConfirmationWorker, type: :job do
  let(:instance) { described_class.new }
  let(:user) { FactoryBot.create(:admin) }
  let(:user_phone) { FactoryBot.create(:user_phone, user: user, phone: "2134442323") }

  it "adds the phone for the user" do
    expect(user_phone.confirmed?).to be_falsey
    expect(user_phone.notifications.count).to eq 0
    user.reload
    expect(user.phone_waiting_confirmation?).to be_truthy
    expect(user.general_alerts).to eq([])
    VCR.use_cassette("user_phone_confirmation_worker", match_requests_on: [:path]) do
      instance.perform(user_phone.id)
    end
    user_phone.reload
    expect(user_phone.confirmed?).to be_falsey
    expect(user_phone.notifications.count).to eq 1
    user.reload
    expect(user.phone_waiting_confirmation?).to be_truthy
    # Confirm that admins still get this alert, because we want them to
    expect(user.general_alerts).to eq(["phone_waiting_confirmation"])
  end
end
