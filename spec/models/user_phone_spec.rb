require "rails_helper"

RSpec.describe UserPhone, type: :model do
  describe "find_confirmation_code" do
    let!(:user_phone1) { FactoryBot.create(:user_phone, confirmation_code: "2929292") }
    let!(:user_phone2) { FactoryBot.create(:user_phone, confirmation_code: "2929292", updated_at: Time.current - 3.hours) }
    let!(:user_phone3) { FactoryBot.create(:user_phone, confirmation_code: "2929291") }
    it "finds only confirmation codes in past 30 minutes" do
      expect(user_phone1.user.phone_waiting_confirmation?).to be_truthy
      expect(user_phone2.user.phone_waiting_confirmation?).to be_falsey
      expect(UserPhone.find_confirmation_code("2 92  92 92")).to eq user_phone1
      expect(UserPhone.find_confirmation_code("02 92 92 9")).to be_blank
      UserPhone.find_confirmation_code("2 92 92 \n92").confirm!
      user_phone1.reload
      expect(user_phone1.confirmed?).to be_truthy
      expect(user_phone1.confirmed_at).to be_within(1).of Time.current
      expect(user_phone1.user.phone_waiting_confirmation?).to be_falsey
    end
  end

  describe "factory" do
    let(:user_phone) { FactoryBot.create(:user_phone) }
    it "is valid" do
      expect(user_phone).to be_valid
    end
  end

  describe "add_phone_for_user_id" do
    let(:user) { FactoryBot.create(:user) }
    let(:phone) { "2342342345" }

    it "adds a user_phone" do
      expect(user.phone).to be_blank
      VCR.use_cassette("user_phone-add_phone_for_user_id", match_requests_on: [:path]) do
        Sidekiq::Testing.inline! {
          expect {
            user_phone = UserPhone.add_phone_for_user_id(user.id, phone)
            og_confirmation_code = user_phone.confirmation_code

            user_phone2 = UserPhone.add_phone_for_user_id(user.id, phone)
            expect(user_phone2.id).to eq user_phone.id
            expect(user_phone2.confirmation_code).to eq og_confirmation_code
          }.to change(UserPhone, :count).by 1
        }
      end

      user.reload
      expect(user.phone).to be_blank
      expect(user.user_phones.count).to eq 1

      user_phone = user.user_phones.first
      expect(user_phone.confirmed?).to be_falsey
      expect(user_phone.confirmation_code).to be_present
      expect(user_phone.confirmation_code.length).to be < 8
      expect(user_phone.confirmation_message).to eq "Bike Index confirmation code:  #{user_phone.confirmation_display}"
      expect(user_phone.notifications.count).to eq 1
      og_confirmation_code = user_phone.confirmation_code

      notification = user_phone.notifications.first
      expect(notification.kind).to eq "phone_verification"
      expect(notification.message_channel).to eq "text"
      expect(notification.user).to eq user
      expect(notification.twilio_sid).to be_present

      # But, if updated more than 2 minutes ago, send another
      user_phone.update_column :updated_at, Time.current - 5.minutes
      expect(user_phone.resend_confirmation?).to be_truthy
      VCR.use_cassette("user_phone-add_phone_for_user_id_again", match_requests_on: [:path]) do
        Sidekiq::Testing.inline! { UserPhone.add_phone_for_user_id(user.id, phone) }
      end
      user_phone.reload
      expect(user_phone.confirmation_code).to_not eq og_confirmation_code
      expect(user_phone.notifications.count).to eq 2
    end
  end
end
