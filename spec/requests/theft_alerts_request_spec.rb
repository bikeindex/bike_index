require "rails_helper"

RSpec.describe TheftAlertsController, type: :request, vcr: true do
  describe "POST /bikes/:bike_id/theft_alerts" do
    let(:theft_alert_plan) { FactoryBot.create(:theft_alert_plan) }
    let(:bike) { FactoryBot.create(:ownership_stolen).bike }

    before do
      log_in bike.owner
      expect(Payment.count).to eq(0)
      expect(TheftAlert.count).to eq(0)
    end

    it "redirects back, creating the theft alert and payment if the payment succeeds" do
      post "/theft_alerts",
        theft_alert_plan_id: theft_alert_plan.id,
        bike_id: bike.id,
        stripe_token: stripe_token.id,
        stripe_amount: 100,
        stripe_email: current_user.email

      expect(Payment.count).to eq(1)
      expect(TheftAlert.count).to eq(1)

      new_theft_alert = TheftAlert.first
      expect(new_theft_alert.status).to eq("pending")
      expect(new_theft_alert.payment).to be_a(Payment)

      expect(response).to redirect_to(edit_bike_url(bike, params: { page: :alert }))
      expect(flash[:success]).to match(/order is pending/i)
    end

    it "redirects to the bike edit page with flash if the creation request fails" do
      invalid_plan_id = 999

      post "/theft_alerts",
           theft_alert_plan_id: invalid_plan_id,
           bike_id: bike.id,
           stripe_token: stripe_token.id,
           stripe_amount: 100,
           stripe_email: current_user.email

      expect(Payment.count).to eq(0)
      expect(TheftAlert.count).to eq(0)

      expect(response).to redirect_to(edit_bike_url(bike, params: { page: :alert }))
      expect(flash[:error]).to match(/unable to process your order/i)
    end

    it "redirects to the bike edit page with flash if the payment request fails" do
      post "/theft_alerts",
           theft_alert_plan_id: theft_alert_plan.id,
           bike_id: bike.id,
           stripe_token: stripe_token_declined.id,
           stripe_amount: 100,
           stripe_email: current_user.email

      expect(Payment.count).to eq(0)
      expect(TheftAlert.count).to eq(1)

      new_theft_alert = TheftAlert.first
      expect(new_theft_alert.status).to eq("pending")
      expect(new_theft_alert.payment).to eq(nil)

      expect(response).to redirect_to(edit_bike_url(bike, params: { page: :alert }))
      expect(flash[:error]).to match(/unable to complete payment/i)
    end

    context "given an unauthenticated user" do
      it "it redirects to the bikes url" do
        post "/theft_alerts", theft_alert_plan_id: 1, bike_id: 1
        expect(response).to redirect_to(bikes_url)
      end
    end
  end
end
