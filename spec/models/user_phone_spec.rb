require 'rails_helper'

RSpec.describe UserPhone, type: :model do
  describe "factory" do
    let(:user_phone) { FactoryBot.create(:user_phone) }
    it "is valid" do
      expect(user_phone).to be_valid
    end
  end

  describe "add_phone_for_user_id" do
    let(:user) { FactoryBot.create(:user) }
    let(:phone) { "1231231234" }
    it "adds a user_phone" do
      expect(user.phone).to be_blank
      VCR.use_cassette("user_phone-add_phone_for_user_id", match_requests_on: [:path]) do
        Sidekiq::Testing.inline! {
          expect {
            UserPhone.add_phone_for_user_id(user.id, phone)
          }.to change(UserPhone, :count).by 1
        }
      end

      user.reload
      expect(user.phone).to eq phone
      expect(user.user_phones.count).to eq 1

      user_phone = user.user_phones.first
      expect(user_phone.confirmed?).to be_falsey
      expect(user_phone.confirmation_code).to be_present
      expect(user_phone.confirmation_code.length).to be < 8
      expect(user_phone.notifications.count).to eq 1

      notification = user_phone.notifications.first
      expect(notification.kind).to eq "phone_verification"
      expect(notification.message_channel).to eq "text"
      expect(notification.user).to eq user
      expect(notification.twilio_sid).to be_present
    end

    context "user has a phone" do
      it "does not clobber the users phone"
    end
  end
end
