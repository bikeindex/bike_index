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

  describe "apple verification" do
    it "responds with verification" do
      get "/.well-known/apple-developer-merchantid-domain-association"
      expect(response.code).to eq "200"
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
      let(:kind) { "donation" }
      let(:payment) { Payment.create(stripe_id: stripe_id, payment_method: "stripe", amount: nil, kind: kind) }
      it "renders" do
        expect(payment).to be_valid
        expect(payment.reload.email).to be_blank
        expect(payment.paid?).to be_falsey
        expect(payment.kind).to eq "donation"
        expect(payment.amount_cents).to eq 0
        VCR.use_cassette("payments_controller-success", match_requests_on: [:method], re_record_interval: re_record_interval) do
          Sidekiq::Worker.clear_all
          ActionMailer::Base.deliveries = []
          expect(Notification.count).to eq 0
          Sidekiq::Testing.inline! do
            get "#{base_url}/success?session_id=#{stripe_id}"
          end
          expect(response.code).to eq("200")
          expect(response).to render_template("success")
          expect(flash).to_not be_present
          expect(assigns(:payment)&.id).to eq payment.id
          payment.reload
          expect(payment.reload.email).to eq "seth@bikeindex.org"
          expect(payment.paid?).to be_truthy
          expect(payment.kind).to eq "donation"
          expect(payment.amount_cents).to eq 5000

          expect(ActionMailer::Base.deliveries.count).to eq 2
          expect(Notification.count).to eq 2
          expect(Notification.pluck(:kind)).to match_array(%w[receipt donation_standard])
        end
      end
      context "with current_user" do
        include_context :request_spec_logged_in_as_user
        let(:stripe_id) { "cs_test_a1OjyvijhWCbD9a9qWzUfM7UisfeWgROJx7tEF8Nc92PCP1uR1vjmXngCa" }
        let(:customer_stripe_id) { "cus_JmR9ccDp8JD2Mo" }
        let(:kind) { "payment" }
        it "renders" do
          expect(current_user.reload.stripe_id).to be_blank
          expect(payment).to be_valid
          expect(payment.reload.email).to be_blank
          expect(payment.paid?).to be_falsey
          expect(payment.amount_cents).to eq 0
          VCR.use_cassette("payments_controller-success-customer", match_requests_on: [:method], re_record_interval: re_record_interval) do
            Sidekiq::Worker.clear_all
            ActionMailer::Base.deliveries = []
            expect(Notification.count).to eq 0
            Sidekiq::Testing.inline! do
              get "#{base_url}/success?session_id=#{stripe_id}"
            end
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

          expect(ActionMailer::Base.deliveries.count).to eq 1
          expect(Notification.count).to eq 1
          expect(Notification.pluck(:kind)).to match_array(%w[receipt])
        end
      end
    end
  end

  describe "create" do
    it "makes a onetime payment" do
      VCR.use_cassette("payments_controller-onetime-nouser", match_requests_on: [:method], re_record_interval: re_record_interval) do
        Sidekiq::Worker.clear_all
        ActionMailer::Base.deliveries = []
        expect(Notification.count).to eq 0
        Sidekiq::Testing.inline! do
          expect {
            post base_url, params: {
              is_arbitrary: false,
              payment: {
                referral_source: "stuffffffff",
                amount_cents: 4000,
                currency: "USD",
                kind: "payment"
              }
            }
          }.to change(Payment, :count).by(1)
        end
        payment = Payment.last
        expect(payment.user_id).to be_blank
        expect(payment.stripe_id).to be_present
        expect(payment.kind).to eq "payment"
        expect(payment.currency).to eq "USD"
        expect(payment.amount_cents).to eq 4000
        expect(payment.paid_at).to be_blank # Ensure this gets set
        expect(payment.paid?).to be_falsey
        expect(payment.referral_source).to eq "stuffffffff"

        # No deliveries, because the payment hasn't been completed
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end
    context "with invalid amount" do
      shared_examples "redirects back and shows flash message" do
        it "does not raise an error" do
          expect {
            post base_url, params: {
              is_arbitrary: false,
              payment: {
                referral_source: "stuffffffff",
                amount_cents: amount_cents,
                currency: "USD",
                kind: "payment"
              }
            }
            expect(response).to redirect_to(new_payment_path)
            expect(flash[:notice]).to match(/valid amount/)
          }.to change(Payment, :count).by(0)
        end
      end
      context "with blank amount" do
        let(:amount_cents) { " " }

        include_examples "redirects back and shows flash message"
      end
      context "with 0" do
        let(:amount_cents) { "000" }

        include_examples "redirects back and shows flash message"
      end
      context "with to large amount" do
        let(:amount_cents) { 100000000 }

        include_examples "redirects back and shows flash message"
      end
    end

    context "with user" do
      include_context :request_spec_logged_in_as_user
      it "makes a onetime payment with current user" do
        expect(current_user.reload.stripe_id).to be_blank
        VCR.use_cassette("payments_controller-donation", match_requests_on: [:method], re_record_interval: re_record_interval) do
          expect {
            post base_url, params: {
              is_arbitrary: false,
              payment: {
                amount_cents: "4000",
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
          expect(payment.paid_at).to be_blank # Ensure this gets set
          expect(payment.paid?).to be_falsey
          expect(payment.stripe_customer).to be_blank
        end
      end
      context "user is a stripe customer" do
        let(:customer_stripe_id) { "cus_JmR9ccDp8JD2Mo" }
        let(:current_user) { FactoryBot.create(:user_confirmed, email: "stripetest@bikeindex.org", stripe_id: customer_stripe_id) }

        it "adds the customer" do
          VCR.use_cassette("payments_controller-donation-customer", match_requests_on: [:method], re_record_interval: re_record_interval) do
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
            expect(payment.paid_at).to be_blank # Ensure this gets set
            expect(payment.paid?).to be_falsey
            expect(payment.stripe_customer).to be_present
            expect(payment.stripe_customer.id).to eq customer_stripe_id
          end
        end
      end
    end
  end
end
