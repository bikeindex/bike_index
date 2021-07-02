require "rails_helper"

base_url = "/payments"
RSpec.describe PaymentsController, type: :request do
  let(:re_record_interval) { 30.days }

  describe "new" do
    context "with user" do
      include_context :request_spec_logged_in_as_user
      before { current_user.update(alert_slugs: ["has_stolen_bike_without_location"]) }
      it "renders" do
        get "#{base_url}/new"
        expect(response.code).to eq("200")
        expect(response).to render_template("new")
        expect(flash).to_not be_present
        expect(assigns(:show_general_alert)).to be_falsey
      end
    end
    context "without user" do
      it "renders" do
        get "#{base_url}/new"
        expect(response.code).to eq("200")
        expect(response).to render_template("new")
        expect(flash).to_not be_present
        expect(assigns(:show_general_alert)).to be_falsey
      end
    end
  end

  describe "success" do
    it "renders" do
      get "#{base_url}/success"
      expect(response.code).to eq("200")
      expect(response).to render_template("success")
      expect(flash).to_not be_present
      expect(assigns(:payment)&.id).to be_blank
    end
    context "with payment" do
      let(:payment) { FactoryBot.create(:payment, user: nil, email: "example@bikeindex.org") }
      it "renders" do
        get "#{base_url}/success?payment_id=#{payment.id}"
        expect(response.code).to eq("200")
        expect(response).to render_template("success")
        expect(flash).to_not be_present
        expect(assigns(:payment)&.id).to eq payment.id
      end
    end
  end

  describe "create" do
    it "makes a onetime donation" do
      VCR.use_cassette("payments_controller-onetime-nouser", match_requests_on: [:path], re_record_interval: re_record_interval) do
        expect {
          post base_url, params: {
            is_arbitrary: false,
            payment: {
              amount_cents: 4000,
              currency: "USD",
              kind: "payment"
            }
          }
        }.to change(Payment, :count).by(1)
        payment = Payment.last
        expect(payment.user_id).to be_blank
        expect(payment.stripe_id).to be_present
        expect(payment.kind).to eq "payment"
        expect(payment.currency).to eq "USD"
        expect(payment.first_payment_date).to be_present
        expect(payment.last_payment_date).to_not be_present
      end
    end
    # context "with user" do
    #   include_context :request_spec_logged_in_as_user
    #   it "makes a onetime payment with current user" do
    #     expect(current_user.reload.stripe_id).to be_blank
    #     VCR.use_cassette("payments_controller-onetime", match_requests_on: [:path], re_record_interval: re_record_interval) do
    #       expect {
    #         post base_url, params: {
    #           stripe_token: stripe_token.id,
    #           stripe_email: current_user.email,
    #           stripe_amount: 4000
    #         }
    #       }.to change(Payment, :count).by(1)
    #       payment = Payment.last
    #       expect(payment.user_id).to eq(current_user.id)
    #       current_user.reload
    #       expect(current_user.stripe_id).to be_present
    #       expect(payment.stripe_id).to be_present
    #       expect(payment.first_payment_date).to be_present
    #       expect(payment.last_payment_date).to_not be_present
    #     end
    #   end
    #   context "payment" do

    #   end

    # context "email of signed up user" do
    #   it "makes a onetime payment with email for signed up user" do
    #     VCR.use_cassette("payments_controller-email", match_requests_on: [:path], re_record_interval: re_record_interval) do
    #       expect {
    #         post base_url, params: {
    #           stripe_token: stripe_token.id,
    #           stripe_amount: 4000,
    #           stripe_email: user.email,
    #           stripe_plan: "",
    #           stripe_subscription: ""
    #         }
    #       }.to change(Payment, :count).by(1)
    #       payment = Payment.last
    #       expect(payment.user_id).to eq(user.id)
    #       user.reload
    #       expect(user.stripe_id).to be_present
    #       expect(payment.stripe_id).to be_present
    #       expect(payment.first_payment_date).to be_present
    #       expect(payment.last_payment_date).to_not be_present
    #       expect(payment.donation?).to be_truthy
    #     end
    #   end
    # end
    # context "no user email on file" do
    #   it "makes a onetime payment with no user, but associate with stripe" do
    #     VCR.use_cassette("payments_controller-noemail", match_requests_on: [:path], re_record_interval: re_record_interval) do
    #       expect {
    #         post base_url, params: {
    #           stripe_token: stripe_token.id,
    #           stripe_amount: 4000,
    #           stripe_email: "test_user@test.com",
    #           is_payment: 1
    #         }
    #       }.to change(Payment, :count).by(1)
    #       payment = Payment.last
    #       expect(payment.email).to eq("test_user@test.com")
    #       expect(payment.stripe_id).to be_present
    #       expect(payment.first_payment_date).to be_present
    #       expect(payment.last_payment_date).to_not be_present
    #       expect(payment.donation?).to be_falsey
    #       expect(payment.payment?).to be_truthy
    #     end
    #   end
    # end
  end
end
