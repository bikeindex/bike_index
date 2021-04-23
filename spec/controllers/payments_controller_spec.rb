require "rails_helper"

RSpec.describe PaymentsController, type: :controller do
  let(:re_record_interval) { 30.days }
  let(:user) { FactoryBot.create(:user_confirmed) }

  describe "new" do
    context "with user" do
      before do
        user.update(general_alerts: ["has_stolen_bikes_without_locations"])
        set_current_user(user)
      end
      it "renders" do
        get :new
        expect(response.code).to eq("200")
        expect(response).to render_template("new")
        expect(flash).to_not be_present
        expect(assigns(:show_general_alert)).to be_falsey
      end
    end
    context "without user" do
      it "renders" do
        get :new
        expect(response.code).to eq("200")
        expect(response).to render_template("new")
        expect(flash).to_not be_present
        expect(assigns(:show_general_alert)).to be_falsey
      end
    end
  end

  describe "create" do
    context "with user" do
      before do
        set_current_user(user)
      end
      it "makes a onetime payment with current user (and renders with revised_layout if suppose to)" do
        VCR.use_cassette("payments_controller-onetime", match_requests_on: [:method], re_record_interval: re_record_interval) do
          expect {
            post :create, params: {
              stripe_token: stripe_token.id,
              stripe_email: user.email,
              stripe_amount: 4000
            }
          }.to change(Payment, :count).by(1)
          payment = Payment.last
          expect(payment.user_id).to eq(user.id)
          user.reload
          expect(user.stripe_id).to be_present
          expect(payment.stripe_id).to be_present
          expect(payment.first_payment_date).to be_present
          expect(payment.last_payment_date).to_not be_present
        end
      end

      it "signs up for a plan" do
        VCR.use_cassette("payments_controller-plan", match_requests_on: [:method], re_record_interval: re_record_interval) do
          expect {
            post :create, params: {
              stripe_token: stripe_token.id,
              stripe_email: user.email,
              stripe_amount: 4000,
              stripe_subscription: 1,
              stripe_plan: "01"
            }
          }.to change(Payment, :count).by(1)
          payment = Payment.last
          expect(payment.is_recurring).to be_truthy
          expect(payment.user_id).to eq user.id
          user.reload
          expect(user.stripe_id).to be_present
          expect(payment.stripe_id).to be_present
          expect(payment.first_payment_date).to be_present
          expect(payment.last_payment_date).to_not be_present
        end
      end
    end

    context "email of signed up user" do
      it "makes a onetime payment with email for signed up user" do
        VCR.use_cassette("payments_controller-email", match_requests_on: [:method], re_record_interval: re_record_interval) do
          expect {
            post :create, params: {
              stripe_token: stripe_token.id,
              stripe_amount: 4000,
              stripe_email: user.email,
              stripe_plan: "",
              stripe_subscription: ""
            }
          }.to change(Payment, :count).by(1)
          payment = Payment.last
          expect(payment.user_id).to eq(user.id)
          user.reload
          expect(user.stripe_id).to be_present
          expect(payment.stripe_id).to be_present
          expect(payment.first_payment_date).to be_present
          expect(payment.last_payment_date).to_not be_present
          expect(payment.donation?).to be_truthy
        end
      end
    end
    context "no user email on file" do
      it "makes a onetime payment with no user, but associate with stripe" do
        VCR.use_cassette("payments_controller-noemail", match_requests_on: [:method], re_record_interval: re_record_interval) do
          expect {
            post :create, params: {
              stripe_token: stripe_token.id,
              stripe_amount: 4000,
              stripe_email: "test_user@test.com",
              is_payment: 1
            }
          }.to change(Payment, :count).by(1)
          payment = Payment.last
          expect(payment.email).to eq("test_user@test.com")
          expect(payment.stripe_id).to be_present
          expect(payment.first_payment_date).to be_present
          expect(payment.last_payment_date).to_not be_present
          expect(payment.donation?).to be_falsey
          expect(payment.payment?).to be_truthy
        end
      end
    end
  end
end
