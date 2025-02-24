require "rails_helper"

re_record_interval = 30.days

RSpec.describe Bikes::PromotedAlertsController, type: :request, vcr: true, match_requests_on: [:method], re_record_interval: re_record_interval do
  let(:promoted_alert_plan) { FactoryBot.create(:promoted_alert_plan) }
  let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, :with_stolen_record, user: current_user) }
  let(:stolen_record) { bike.current_stolen_record }
  let(:base_url) { "/bikes/#{bike.to_param}/promoted_alert" }
  include_context :request_spec_logged_in_as_user

  describe "new" do
    let(:promoted_alert_plan2) { FactoryBot.create(:promoted_alert_plan) }
    before { promoted_alert_plan && promoted_alert_plan2 }
    it "renders" do
      get "#{base_url}/new"
      expect(response.code).to eq("200")
      expect(response).to render_template("new")
      expect(flash).to_not be_present
      expect(assigns(:show_general_alert)).to be_falsey
      expect(assigns(:selected_promoted_alert_plan)&.id).to eq promoted_alert_plan2.id
      expect(assigns(:promoted_alerts).pluck(:id)).to eq([])
    end
    context "existing theft alert" do
      let!(:promoted_alert_paid) do
        FactoryBot.create(:promoted_alert, :paid, :ended,
          user: promoted_alert_user,
          promoted_alert_plan: promoted_alert_plan,
          stolen_record: stolen_record)
      end
      let(:promoted_alert_user) { current_user }
      it "renders theft alert" do
        expect(stolen_record.reload.promoted_alerts.pluck(:id)).to eq([promoted_alert_paid.id])
        expect(stolen_record.promoted_alerts.active.pluck(:id)).to eq([])
        get "#{base_url}/new"
        expect(response.code).to eq("200")
        expect(response).to render_template("new")
        expect(flash).to_not be_present
        expect(assigns(:show_general_alert)).to be_falsey
        expect(assigns(:selected_promoted_alert_plan)&.id).to eq promoted_alert_plan2.id
        expect(assigns(:promoted_alerts).pluck(:id)).to eq([promoted_alert_paid.id])
      end
      context "not users" do
        let(:promoted_alert_user) { FactoryBot.create(:user_confirmed) }
        it "doesn't render" do
          get "#{base_url}/new"
          expect(response.code).to eq("200")
          expect(response).to render_template("new")
          expect(flash).to_not be_present
          expect(assigns(:show_general_alert)).to be_falsey
          expect(assigns(:selected_promoted_alert_plan)&.id).to eq promoted_alert_plan2.id
          expect(assigns(:promoted_alerts).pluck(:id)).to eq([])
        end
        context "superadmin" do
          let(:current_user) { FactoryBot.create(:admin) }
          it "renders" do
            get "#{base_url}/new"
            expect(response.code).to eq("200")
            expect(response).to render_template("new")
            expect(flash).to_not be_present
            expect(assigns(:show_general_alert)).to be_falsey
            expect(assigns(:selected_promoted_alert_plan)&.id).to eq promoted_alert_plan2.id
            expect(assigns(:promoted_alerts).pluck(:id)).to eq([promoted_alert_paid.id])
          end
        end
      end
    end
    context "current user not owner of bike" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, :with_stolen_record) }
      it "flash errors and redirects" do
        get "#{base_url}/new"
        expect(response).to redirect_to(bike_path(bike))
        expect(flash[:error]).to match(/don't own that bike/)
      end
    end
    context "not stolen bike" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: current_user) }
      it "redirects without flash error" do
        get "#{base_url}/new"
        expect(response).to redirect_to(edit_bike_path(bike, edit_template: "bike_details"))
        expect(flash).to be_blank
      end
    end
  end

  describe "create" do
    include_context :request_spec_logged_in_as_user
    def expect_promoted_alert_to_be_created
      promoted_alert = PromotedAlert.last
      expect(promoted_alert.promoted_alert_plan_id).to eq promoted_alert_plan.id
      expect(promoted_alert.user_id).to eq current_user.id
      expect(promoted_alert.bike_id).to eq bike.id
      expect(promoted_alert.stolen_record_id).to eq bike.current_stolen_record_id
      expect(promoted_alert.paid?).to be_falsey
      expect(promoted_alert.payment_id).to be_present

      payment = promoted_alert.payment
      expect(payment.user_id).to eq current_user.id
      expect(payment.stripe_id).to be_present
      expect(payment.kind).to eq "promoted_alert"
      expect(payment.currency_name).to eq "USD"
      expect(payment.amount_cents).to eq promoted_alert_plan.amount_cents
      expect(payment.paid_at).to be_blank # Ensure this gets set
      expect(payment.paid?).to be_falsey
    end

    it "successfully creates" do
      expect(bike.current_stolen_record_id).to be_present
      expect(Payment.count).to eq 0
      expect(PromotedAlert.count).to eq 0
      Sidekiq::Job.clear_all
      ActionMailer::Base.deliveries = []
      expect(Notification.count).to eq 0
      Sidekiq::Testing.inline! do
        expect {
          post base_url, params: {
            promoted_alert_plan_id: promoted_alert_plan.id,
            bike_id: bike.id
          }
        }.to change(PromotedAlert, :count).by(1)
      end
      expect_promoted_alert_to_be_created

      # No deliveries, because the payment hasn't been completed
      expect(Notification.count).to eq 0
      expect(ActionMailer::Base.deliveries.count).to eq 0
    end
    context "passing alert_image" do
      let!(:image1) { FactoryBot.create(:public_image, filename: "bike-#{bike.id}.jpg", imageable: bike) }
      let!(:image2) { FactoryBot.create(:public_image, filename: "bike-#{bike.id}.jpg", imageable: bike) }
      it "updates the alert image" do
        stolen_record.reload.current_alert_image
        expect(stolen_record.reload.alert_image).to be_present
        og_alert_image_id = stolen_record.alert_image&.id # Fails without internet connection
        expect(Payment.count).to eq 0
        expect(PromotedAlert.count).to eq 0
        Sidekiq::Job.clear_all
        ActionMailer::Base.deliveries = []
        expect(Notification.count).to eq 0

        Sidekiq::Testing.inline! do
          expect {
            post base_url, params: {
              promoted_alert_plan_id: promoted_alert_plan.id,
              bike_id: bike.id,
              selected_bike_image_id: image2.id
            }
          }.to change(PromotedAlert, :count).by(1)
        end
        expect_promoted_alert_to_be_created

        expect(stolen_record.reload.alert_image).to be_present
        expect(stolen_record.alert_image.id).to_not eq og_alert_image_id

        # No deliveries, because the payment hasn't been completed
        expect(Notification.count).to eq 0
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end
  end

  describe "show" do
    let(:stripe_id) { "cs_test_a11HYkpTmOUEdKM02Xx8zlX7pqUFhXW1P6CBRVhm09l3BCiFs0MxBs7NIY" }
    let(:promoted_alert) { FactoryBot.create(:promoted_alert, promoted_alert_plan: promoted_alert_plan, stolen_record: bike.current_stolen_record) }
    let(:payment) { Payment.create(stripe_id: stripe_id, user: current_user, payment_method: "stripe", amount: nil, kind: "promoted_alert", promoted_alert: promoted_alert) }
    it "marks as paid" do
      expect(payment.reload.paid?).to be_falsey
      expect(payment.amount_cents).to eq 0
      get "#{base_url}?session_id=#{stripe_id}"
      expect(response.code).to eq("200")
      expect(response).to render_template("show")
      expect(flash).to_not be_present
      expect(assigns(:show_general_alert)).to be_falsey

      expect(payment.reload.paid?).to be_truthy
      expect(payment.amount_cents).to eq 3999
    end
  end
end
