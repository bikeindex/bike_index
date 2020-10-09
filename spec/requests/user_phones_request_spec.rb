require "rails_helper"

RSpec.describe UserPhonesController, type: :request do
  let(:base_url) { "/user_phones" }

  it "redirects if user not present" do
    expect {
      post base_url, params: {phone: "7178386789"}
    }.to_not change(UserPhone, :count)
    expect(response).to redirect_to(/session\/new/)
  end

  context "with user present" do
    include_context :request_spec_logged_in_as_user
    describe "create" do
      it "creates" do
        expect(current_user).to be_present
        Sidekiq::Worker.clear_all
        Sidekiq::Testing.inline! {
          VCR.use_cassette("user_phones_controller-create", match_requests_on: [:path]) do
            expect {
              post base_url, params: {phone: "7178386789"}
            }.to change(UserPhone, :count).by 1
          end

          current_user.reload
          expect(current_user.user_phones.count).to eq 1
          expect(current_user.phone_waiting_confirmation?).to be_truthy
          expect(current_user.general_alerts).to eq(["phone_waiting_confirmation"])

          user_phone = current_user.user_phones.first
          expect(user_phone.confirmed?).to be_falsey
          expect(user_phone.notifications.count).to eq 1

          # And then, so we don't have to set everything up again, test confirmation in here
          post base_url, params: {confirmation_code: user_phone.confirmation_code}

          current_user.reload
          expect(current_user.phone_waiting_confirmation?).to be_falsey
          expect(current_user.user_phones.count).to eq 1
          expect(current_user.general_alerts).to eq([])

          user_phone.reload
          expect(user_phone.confirmed?).to be_truthy
          expect(user_phone.confirmed_at).to be_within(5).of Time.current
        }
      end
    end
  end
end
