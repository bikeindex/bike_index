require "rails_helper"

RSpec.describe TheftAlertsController, type: :request, vcr: true do
  describe "POST /bikes/:bike_id/theft_alerts" do
    let(:theft_alert_plan) { FactoryBot.create(:theft_alert_plan) }
    let(:bike) { FactoryBot.create(:ownership_stolen).bike }
    let(:current_user) { bike.owner }

    before do
      log_in current_user
      expect(Payment.count).to eq(0)
      expect(TheftAlert.count).to eq(0)
    end

    context "given the theft alert and payment both succeed" do
      it "redirects to purchase confirmation template" do
        Sidekiq::Worker.clear_all
        ActionMailer::Base.deliveries = []
        expect(Notification.count).to eq 0
        Sidekiq::Testing.inline! do
          post "/theft_alerts",
            params: {
              theft_alert_plan_id: theft_alert_plan.id,
              bike_id: bike.id,
              stripe_token: stripe_token.id,
              stripe_amount: 100,
              stripe_email: current_user.email,
              stripe_currency: "USD"
            }
        end

        expect(Payment.count).to eq(1)
        expect(TheftAlert.count).to eq(1)

        new_theft_alert = TheftAlert.first
        expect(new_theft_alert.status).to eq("pending")
        expect(new_theft_alert.payment).to be_a(Payment)
        expect(new_theft_alert.payment.stripe_kind).to eq "stripe_charge"

        purchase_confirmation = edit_bike_url(bike, params: {edit_template: :alert_purchase_confirmation})
        expect(response).to redirect_to(purchase_confirmation)

        expect(Notification.count).to eq 1
        expect(Notification.pluck(:kind)).to eq(["receipt"])
        expect(ActionMailer::Base.deliveries.count).to eq 1
        mail = ActionMailer::Base.deliveries.last
        expect(mail.subject).to eq "Thank you for supporting Bike Index!"
      end
    end

    context "given the creation request fails" do
      it "redirects to the bike edit edit_template with a flash message" do
        invalid_plan_id = 999

        post "/theft_alerts",
          params: {
            theft_alert_plan_id: invalid_plan_id,
            bike_id: bike.id,
            stripe_token: stripe_token.id,
            stripe_amount: 100,
            stripe_email: current_user.email,
            stripe_currency: "USD"
          }

        expect(Payment.count).to eq(0)
        expect(TheftAlert.count).to eq(0)

        expect(response).to redirect_to(edit_bike_url(bike, params: {edit_template: :alert_purchase}))
        expect(flash[:error]).to match(/unable to process your order/i)
      end
    end

    context "given the payment request fails" do
      it "redirects to the bike edit edit_template with a flash message" do
        post "/theft_alerts",
          params: {
            theft_alert_plan_id: theft_alert_plan.id,
            bike_id: bike.id,
            stripe_token: stripe_token_declined.id,
            stripe_amount: 100,
            stripe_email: current_user.email,
            stripe_currency: "USD"
          }

        expect(Payment.count).to eq(0)
        expect(TheftAlert.count).to eq(1)

        new_theft_alert = TheftAlert.first
        expect(new_theft_alert.status).to eq("pending")
        expect(new_theft_alert.payment).to eq(nil)

        expect(response).to redirect_to(edit_bike_url(bike, params: {edit_template: :alert_purchase}))
        expect(flash[:error]).to match(/unable to complete payment/i)

        expect(Notification.count).to eq 0
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end

    context "given an unauthenticated user" do
      it "it redirects to the bikes url" do
        post "/theft_alerts", params: {theft_alert_plan_id: 1, bike_id: 1}
        expect(response).to redirect_to(bikes_url)
      end
    end
  end
end
