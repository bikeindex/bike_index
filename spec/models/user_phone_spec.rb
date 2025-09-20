require "rails_helper"

RSpec.describe UserPhone, type: :model do
  describe "find_confirmation_code" do
    let!(:user_phone1) { FactoryBot.create(:user_phone, confirmation_code: "2929292") }
    let!(:user_phone2) { FactoryBot.create(:user_phone, phone: "1112223333", confirmation_code: "2929292", updated_at: Time.current - 3.hours) }
    let!(:user_phone3) { FactoryBot.create(:user_phone, phone: "1112223333", confirmation_code: "2929291") }
    it "finds only confirmation codes in past 30 minutes" do
      expect(user_phone1).to be_valid # Ensure working factory
      expect(user_phone1.user.phone_waiting_confirmation?).to be_truthy
      expect(user_phone2.user.phone_waiting_confirmation?).to be_falsey
      expect(UserPhone.find_confirmation_code("2 92  92 92")).to eq user_phone1
      expect(UserPhone.find_confirmation_code("02 92 92 9")).to be_blank
      UserPhone.find_confirmation_code("2 92 92 \n92").confirm!
      user_phone1.reload
      expect(user_phone1.confirmed?).to be_truthy
      expect(user_phone1.confirmed_at).to be_within(1).of Time.current
      user = user_phone1.user
      expect(user.phone_waiting_confirmation?).to be_falsey
      expect(user.phone).to eq nil
      expect(user.current_user_phone).to eq user_phone1.phone
      user.update(phone: user_phone1.phone)
      expect(user.reload.phone).to eq user_phone1.phone
      expect(user.current_user_phone).to eq user_phone1.phone
      expect(User.search_phone("1112223333").pluck(:id)).to match_array([user_phone2.user_id, user_phone3.user_id])
      expect(User.search_phone("11122233").pluck(:id)).to match_array([user_phone2.user_id, user_phone3.user_id])
      expect(User.search_phone("11222333").pluck(:id)).to match_array([user_phone2.user_id, user_phone3.user_id])
    end
  end

  describe "code_display and code_normalize" do
    it "has spaces for legibility" do
      expect(UserPhone.code_display("2929292")).to eq "292 9292"
      expect(UserPhone.code_normalize("292 9292")).to eq "2929292"
    end
  end

  # 017654806966
  describe "confirmation_matches?" do
    let(:user_phone) { UserPhone.new(confirmation_code: "0505032") }
    it "is truthy even with spaces" do
      expect(user_phone.code_display).to eq "050 5032"
      expect(user_phone.confirmation_matches?("050 5032")).to be_truthy
      expect(user_phone.confirmation_matches?("05 0 5 0 32\n\n")).to be_truthy
    end
  end

  describe "add_phone_for_user_id" do
    let(:user) { FactoryBot.create(:user) }
    let(:phone) { "2342342345" }
    before do
      Flipper.enable(:phone_verification)
      UserPhoneConfirmationJob.new # Instantiate for stubbing
      stub_const("UserPhoneConfirmationJob::UPDATE_TWILIO", true)
    end

    it "adds a user_phone" do
      expect(user.phone).to be_blank
      Sidekiq::Job.clear_all
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
      expect(user_phone.confirmation_message).to eq "Bike Index confirmation code:  #{user_phone.code_display}"
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
