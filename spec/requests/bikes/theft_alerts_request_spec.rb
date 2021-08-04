require "rails_helper"

re_record_interval = 30.days

RSpec.describe Bikes::TheftAlertsController, type: :request, vcr: true, match_requests_on: [:method], re_record_interval: re_record_interval do
  let(:theft_alert_plan) { FactoryBot.create(:theft_alert_plan) }
  let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, :with_stolen_record, user: current_user) }
  let(:base_url) { "/bikes/#{bike.to_param}/theft_alert" }
  include_context :request_spec_logged_in_as_user

  describe "new" do
    it "renders" do
      # there need to be 2 plans
      FactoryBot.create(:theft_alert_plan)
      theft_alert_plan2 = FactoryBot.create(:theft_alert_plan)
      get "#{base_url}/new"
      expect(response.code).to eq("200")
      expect(response).to render_template("new")
      expect(flash).to_not be_present
      expect(assigns(:show_general_alert)).to be_falsey
      expect(assigns(:selected_theft_alert_plan)&.id).to eq theft_alert_plan2.id
    end
    context "current user not owner of bike" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, :with_stolen_record) }
      it "flash errors and redirects" do
        get "#{base_url}/new"
        expect(response).to redirect_to(bike_path(bike))
        expect(flash[:error]).to match(/don't own that bike/)
      end
    end
  end

  describe "create" do
    include_context :request_spec_logged_in_as_user

    it "successfully creates" do
      expect(bike.current_stolen_record_id).to be_present
        expect(Payment.count).to eq 0
        expect(TheftAlert.count).to eq 0
        Sidekiq::Worker.clear_all
        ActionMailer::Base.deliveries = []
        expect(Notification.count).to eq 0
        Sidekiq::Testing.inline! do
          expect {
            post base_url, params: {
              theft_alert_plan_id: theft_alert_plan.id,
              bike_id: bike.id,
            }
          }.to change(TheftAlert, :count).by(1)
        end
        theft_alert = TheftAlert.last
        expect(theft_alert.theft_alert_plan_id).to eq theft_alert_plan.id
        expect(theft_alert.user_id).to eq current_user.id
        expect(theft_alert.bike_id).to eq bike.id
        expect(theft_alert.stolen_record_id).to eq bike.current_stolen_record_id
        expect(theft_alert.paid?).to be_falsey
        expect(theft_alert.payment_id).to be_present

        payment = theft_alert.payment
        expect(payment.user_id).to eq current_user.id
        expect(payment.stripe_id).to be_present
        expect(payment.kind).to eq "theft_alert"
        expect(payment.stripe_kind).to eq "stripe_session"
        expect(payment.currency).to eq "USD"
        expect(payment.amount_cents).to eq theft_alert_plan.amount_cents
        expect(payment.first_payment_date).to be_blank # Ensure this gets set
        expect(payment.last_payment_date).to be_blank
        expect(payment.paid?).to be_falsey

        # No deliveries, because the payment hasn't been completed
        expect(ActionMailer::Base.deliveries.count).to eq 0
      # end
    end
    context "alert image" do
      it "updates the alert image"
    end
  end

  #   before do
  #     log_in current_user
  #     expect(Payment.count).to eq(0)
  #     expect(TheftAlert.count).to eq(0)
  #   end

  #   context "given the theft alert and payment both succeed" do
  #     it "redirects to purchase confirmation template" do
  #       Sidekiq::Worker.clear_all
  #       ActionMailer::Base.deliveries = []
  #       expect(Notification.count).to eq 0
  #       Sidekiq::Testing.inline! do
  #         post "/theft_alerts",
  #           params: {
  #             theft_alert_plan_id: theft_alert_plan.id,
  #             bike_id: bike.id,
  #             stripe_token: stripe_token.id,
  #             stripe_amount: 100,
  #             stripe_email: current_user.email,
  #             stripe_currency: "USD"
  #           }
  #       end

  #       expect(Payment.count).to eq(1)
  #       expect(TheftAlert.count).to eq(1)

  #       new_theft_alert = TheftAlert.first
  #       expect(new_theft_alert.status).to eq("pending")
  #       expect(new_theft_alert.payment).to be_a(Payment)
  #       expect(new_theft_alert.payment.stripe_kind).to eq "stripe_charge"

  #       purchase_confirmation = edit_bike_url(bike, params: {edit_template: :alert_purchase_confirmation})
  #       expect(response).to redirect_to(purchase_confirmation)

  #       expect(Notification.count).to eq 1
  #       expect(Notification.pluck(:kind)).to eq(["receipt"])
  #       expect(ActionMailer::Base.deliveries.count).to eq 1
  #       mail = ActionMailer::Base.deliveries.last
  #       expect(mail.subject).to eq "Thank you for supporting Bike Index!"
  #     end
  #   end

  #   context "given the creation request fails" do
  #     it "redirects to the bike edit edit_template with a flash message" do
  #       invalid_plan_id = 999

  #       post "/theft_alerts",
  #         params: {
  #           theft_alert_plan_id: invalid_plan_id,
  #           bike_id: bike.id,
  #           stripe_token: stripe_token.id,
  #           stripe_amount: 100,
  #           stripe_email: current_user.email,
  #           stripe_currency: "USD"
  #         }

  #       expect(Payment.count).to eq(0)
  #       expect(TheftAlert.count).to eq(0)

  #       expect(response).to redirect_to(edit_bike_url(bike, params: {edit_template: :alert}))
  #       expect(flash[:error]).to match(/unable to process your order/i)
  #     end
  #   end

  #   context "given the payment request fails" do
  #     it "redirects to the bike edit edit_template with a flash message" do
  #       post "/theft_alerts",
  #         params: {
  #           theft_alert_plan_id: theft_alert_plan.id,
  #           bike_id: bike.id,
  #           stripe_token: stripe_token_declined.id,
  #           stripe_amount: 100,
  #           stripe_email: current_user.email,
  #           stripe_currency: "USD"
  #         }

  #       expect(Payment.count).to eq(0)
  #       expect(TheftAlert.count).to eq(1)

  #       new_theft_alert = TheftAlert.first
  #       expect(new_theft_alert.status).to eq("pending")
  #       expect(new_theft_alert.payment).to eq(nil)

  #       expect(response).to redirect_to(edit_bike_url(bike, params: {edit_template: :alert}))
  #       expect(flash[:error]).to match(/unable to complete payment/i)

  #       expect(Notification.count).to eq 0
  #       expect(ActionMailer::Base.deliveries.count).to eq 0
  #     end
  #   end

  #   context "given an unauthenticated user" do
  #     it "it redirects to the bikes url" do
  #       post "/theft_alerts", params: {theft_alert_plan_id: 1, bike_id: 1}
  #       expect(response).to redirect_to(bikes_url)
  #     end
  #   end
  # end
end
