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
    context "with stripe_id" do
      let(:stripe_id) { "cs_test_a17wYrWqVcrfgLkOnthsa6r4STYqidDh3gTU8pkUqgGepDZSprYeoT8VxV" }
      let(:payment) { Payment.create(stripe_id: stripe_id, payment_method: "stripe", amount: nil, kind: "donation") }
      it "renders" do
        expect(payment).to be_valid
        expect(payment.reload.email).to be_blank
        expect(payment.paid?).to be_falsey
        expect(payment.kind).to eq "donation"
        expect(payment.amount_cents).to eq 0
        VCR.use_cassette("payments_controller-success", match_requests_on: [:path], re_record_interval: re_record_interval) do
          get "#{base_url}/success?session_id=#{stripe_id}"
          expect(response.code).to eq("200")
          expect(response).to render_template("success")
          expect(flash).to_not be_present
          expect(assigns(:payment)&.id).to eq payment.id
          payment.reload
          expect(payment.reload.email).to eq "seth@bikeindex.org"
          expect(payment.paid?).to be_truthy
          expect(payment.kind).to eq "donation"
          expect(payment.amount_cents).to eq 5000
        end
      end
      context "with current_user" do
        include_context :request_spec_logged_in_as_user
        let(:stripe_id) { "cs_test_a1OjyvijhWCbD9a9qWzUfM7UisfeWgROJx7tEF8Nc92PCP1uR1vjmXngCa" }
        let(:customer_stripe_id) { "cus_JmR9ccDp8JD2Mo" }
        it "renders" do
          expect(current_user.reload.stripe_id).to be_blank
          expect(payment).to be_valid
          expect(payment.reload.email).to be_blank
          expect(payment.paid?).to be_falsey
          expect(payment.amount_cents).to eq 0
          VCR.use_cassette("payments_controller-success-customer", match_requests_on: [:path], re_record_interval: re_record_interval) do
            get "#{base_url}/success?session_id=#{stripe_id}"
            expect(response.code).to eq("200")
            expect(response).to render_template("success")
            expect(flash).to_not be_present
            expect(assigns(:payment)&.id).to eq payment.id
            payment.reload
            expect(payment.reload.email).to eq "testly@bikeindex.org"
            expect(payment.paid?).to be_truthy
            expect(payment.amount_cents).to eq 500000
          end
          expect(current_user.reload.stripe_id).to eq customer_stripe_id
        end
      end
    end
  end

  describe "create" do
    it "makes a onetime payment" do
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
        expect(payment.stripe_kind).to eq "stripe_session"
        expect(payment.currency).to eq "USD"
        expect(payment.amount_cents).to eq 4000
        expect(payment.first_payment_date).to be_blank # Ensure this gets set
        expect(payment.last_payment_date).to be_blank
        expect(payment.paid?).to be_falsey
      end
    end
    context "with user" do
      include_context :request_spec_logged_in_as_user
      it "makes a onetime payment with current user" do
        expect(current_user.reload.stripe_id).to be_blank
        VCR.use_cassette("payments_controller-donation", match_requests_on: [:path], re_record_interval: re_record_interval) do
          expect {
            post base_url, params: {
              is_arbitrary: false,
              payment: {
                amount_cents: 4000,
                currency: "USD",
                kind: "donation"
              }
            }
          }.to change(Payment, :count).by(1)
          payment = Payment.last
          expect(payment.user_id).to eq current_user.id
          expect(payment.stripe_id).to be_present
          expect(payment.kind).to eq "donation"
          expect(payment.currency).to eq "USD"
          expect(payment.amount_cents).to eq 4000
          expect(payment.first_payment_date).to be_blank # Ensure this gets set
          expect(payment.last_payment_date).to be_blank
          expect(payment.paid?).to be_falsey
          expect(payment.stripe_customer).to be_blank
        end
      end
      context "user is a stripe customer" do
        let(:customer_stripe_id) { "cus_JmR9ccDp8JD2Mo" }
        let(:current_user) { FactoryBot.create(:user_confirmed, email: "stripetest@bikeindex.org", stripe_id: customer_stripe_id) }

        it "adds the customer" do
          VCR.use_cassette("payments_controller-donation-customer", match_requests_on: [:path], re_record_interval: re_record_interval) do
            expect {
              post base_url, params: {
                is_arbitrary: false,
                payment: {
                  amount_cents: 7500,
                  currency: "USD",
                  kind: "donation"
                }
              }
            }.to change(Payment, :count).by(1)
            payment = Payment.last
            expect(payment.user_id).to eq current_user.id
            expect(payment.stripe_id).to be_present
            expect(payment.kind).to eq "donation"
            expect(payment.currency).to eq "USD"
            expect(payment.amount_cents).to eq 7500
            expect(payment.first_payment_date).to be_blank # Ensure this gets set
            expect(payment.last_payment_date).to be_blank
            expect(payment.paid?).to be_falsey
            expect(payment.stripe_customer).to be_present
            expect(payment.stripe_customer.id).to eq customer_stripe_id
          end
        end
      end
    end
  end
end
