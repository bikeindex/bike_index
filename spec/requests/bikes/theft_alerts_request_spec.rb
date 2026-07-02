require "rails_helper"

re_record_interval = 30.days

RSpec.describe Bikes::TheftAlertsController, type: :request, vcr: true, match_requests_on: [:method], re_record_interval: re_record_interval do
  let(:theft_alert_plan) { FactoryBot.create(:theft_alert_plan) }
  let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, :with_stolen_record, user: current_user) }
  let(:stolen_record) { bike.current_stolen_record }
  let(:base_url) { "/bikes/#{bike.to_param}/theft_alert" }
  include_context :request_spec_logged_in_as_user

  describe "new" do
    let(:theft_alert_plan2) { FactoryBot.create(:theft_alert_plan) }
    before { theft_alert_plan && theft_alert_plan2 }
    it "renders" do
      get "#{base_url}/new"
      expect(response.code).to eq("200")
      expect(response).to render_template("new")
      expect(flash).to_not be_present
      expect(assigns(:show_general_alert)).to be_falsey
      expect(assigns(:selected_theft_alert_plan)&.id).to eq theft_alert_plan2.id
      expect(assigns(:theft_alerts).pluck(:id)).to eq([])
    end
    context "existing theft alert" do
      let!(:theft_alert_paid) do
        FactoryBot.create(:theft_alert, :paid, :ended,
          user: theft_alert_user,
          theft_alert_plan: theft_alert_plan,
          stolen_record: stolen_record)
      end
      let(:theft_alert_user) { current_user }
      it "renders theft alert" do
        expect(stolen_record.reload.theft_alerts.pluck(:id)).to eq([theft_alert_paid.id])
        expect(stolen_record.theft_alerts.active.pluck(:id)).to eq([])
        get "#{base_url}/new"
        expect(response.code).to eq("200")
        expect(response).to render_template("new")
        expect(flash).to_not be_present
        expect(assigns(:show_general_alert)).to be_falsey
        expect(assigns(:selected_theft_alert_plan)&.id).to eq theft_alert_plan2.id
        expect(assigns(:theft_alerts).pluck(:id)).to eq([theft_alert_paid.id])
      end
      context "not users" do
        let(:theft_alert_user) { FactoryBot.create(:user_confirmed) }
        it "doesn't render" do
          get "#{base_url}/new"
          expect(response.code).to eq("200")
          expect(response).to render_template("new")
          expect(flash).to_not be_present
          expect(assigns(:show_general_alert)).to be_falsey
          expect(assigns(:selected_theft_alert_plan)&.id).to eq theft_alert_plan2.id
          expect(assigns(:theft_alerts).pluck(:id)).to eq([])
        end
        context "superadmin" do
          let(:current_user) { FactoryBot.create(:superuser) }
          it "renders" do
            get "#{base_url}/new"
            expect(response.code).to eq("200")
            expect(response).to render_template("new")
            expect(flash).to_not be_present
            expect(assigns(:show_general_alert)).to be_falsey
            expect(assigns(:selected_theft_alert_plan)&.id).to eq theft_alert_plan2.id
            expect(assigns(:theft_alerts).pluck(:id)).to eq([theft_alert_paid.id])
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
    def expect_theft_alert_to_be_created
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
      expect(payment.currency_name).to eq "USD"
      expect(payment.amount_cents).to eq theft_alert_plan.amount_cents
      expect(payment.paid_at).to be_blank # Ensure this gets set
      expect(payment.paid?).to be_falsey
    end

    it "successfully creates" do
      expect(bike.current_stolen_record_id).to be_present
      expect(Payment.count).to eq 0
      expect(TheftAlert.count).to eq 0
      Sidekiq::Job.clear_all
      ActionMailer::Base.deliveries = []
      expect(Notification.count).to eq 0
      Sidekiq::Testing.inline! do
        expect {
          post base_url, params: {
            theft_alert_plan_id: theft_alert_plan.id,
            bike_id: bike.id
          }
        }.to change(TheftAlert, :count).by(1)
      end
      expect_theft_alert_to_be_created

      # No deliveries, because the payment hasn't been completed
      expect(Notification.count).to eq 0
      expect(ActionMailer::Base.deliveries.count).to eq 0
    end
    context "passing alert_image" do
      let!(:image1) { FactoryBot.create(:public_image, :with_image_file, imageable: bike) }
      let!(:image2) { FactoryBot.create(:public_image, :with_image_file, imageable: bike) }
      it "updates the alert image", :flaky do
        Images::StolenProcessor.update_alert_images(stolen_record)
        expect(stolen_record.reload.images_attached_id).to eq image1.id

        expect(Payment.count).to eq 0
        expect(TheftAlert.count).to eq 0
        Sidekiq::Job.clear_all
        ActionMailer::Base.deliveries = []
        expect(Notification.count).to eq 0

        Sidekiq::Testing.inline! do
          expect {
            post base_url, params: {
              theft_alert_plan_id: theft_alert_plan.id,
              bike_id: bike.id,
              selected_bike_image_id: image2.id
            }
          }.to change(TheftAlert, :count).by(1)
        end
        expect_theft_alert_to_be_created

        expect(stolen_record.reload.images_attached?).to be_truthy
        expect(stolen_record.images_attached_id).to eq image2.id

        # No deliveries, because the payment hasn't been completed
        expect(Notification.count).to eq 0
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end
  end

  describe "show" do
    let(:stripe_id) { "cs_test_a11HYkpTmOUEdKM02Xx8zlX7pqUFhXW1P6CBRVhm09l3BCiFs0MxBs7NIY" }
    let(:theft_alert) { FactoryBot.create(:theft_alert, theft_alert_plan: theft_alert_plan, stolen_record: bike.current_stolen_record) }
    let(:payment) { Payment.create(stripe_id: stripe_id, user: current_user, payment_method: "stripe", amount: nil, kind: "theft_alert", theft_alert: theft_alert) }
    it "marks as paid" do
      expect(payment.reload.paid?).to be_falsey
      expect(payment.amount_cents).to eq 0
      expect(theft_alert.activateable?).to be_falsey
      Sidekiq::Job.clear_all
      get "#{base_url}?session_id=#{stripe_id}"
      expect(response.code).to eq("200")
      expect(response).to render_template("show")
      expect(flash).to_not be_present
      expect(assigns(:show_general_alert)).to be_falsey

      expect(payment.reload.paid?).to be_truthy
      expect(payment.amount_cents).to eq 3999

      expect(theft_alert.reload.paid?).to be_truthy
      expect(theft_alert.activateable?).to be_falsey
      expect(StolenBike::ActivateTheftAlertJob.jobs.count).to eq 0
    end
    context "with an activateable theft_alert" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: current_user) }
      let!(:stolen_record) { FactoryBot.create(:stolen_record, :in_chicago, :with_images, bike:) }
      it "marks as paid and enqueues activation" do
        bike.update(current_stolen_record: stolen_record)
        expect(stolen_record.reload.images_attached?).to be_truthy
        expect(payment.reload.paid?).to be_falsey
        expect(payment.amount_cents).to eq 0
        expect(theft_alert.reload.activateable?).to be_falsey
        expect(theft_alert.missing_photo?).to be_falsey
        expect(theft_alert.bike_not_current?).to be_falsey
        expect(theft_alert.missing_location?).to be_falsey
        Sidekiq::Job.clear_all
        get "#{base_url}?session_id=#{stripe_id}"
        expect(response.code).to eq("200")
        expect(response).to render_template("show")
        expect(flash).to_not be_present
        expect(assigns(:show_general_alert)).to be_falsey

        expect(payment.reload.paid?).to be_truthy
        expect(payment.amount_cents).to eq 3999

        expect(theft_alert.reload.paid?).to be_truthy
        expect(theft_alert.activateable_except_approval?).to be_truthy
        expect(theft_alert.activateable?).to be_truthy
        expect(StolenBike::ActivateTheftAlertJob.jobs.count).to eq 1
      end
    end
  end
end
