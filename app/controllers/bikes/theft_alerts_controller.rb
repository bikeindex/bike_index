module Bikes
  class TheftAlertsController < Bikes::BaseController
    include BikeEditable

    before_action :get_existing_promoted_alerts, except: [:create]

    def new
      return unless setup_edit_template("alert")

      @theft_alert_plans = TheftAlertPlan.active.price_ordered_asc.in_language(I18n.locale)
      @selected_theft_alert_plan =
        @theft_alert_plans.find_by(id: params[:selected_plan_id]) ||
        @theft_alert_plans.order(:amount_cents).second
    end

    def show
      @payment = if params[:session_id].present?
        Payment.where(stripe_id: params[:session_id]).first
      end

      redirect_to new_bike_theft_alert_path(bike_id: @bike.id) unless @payment.present?
      return unless setup_edit_template("alert_purchase_confirmation")

      @payment&.update_from_stripe!
      if @payment.promoted_alert&.activateable?
        BikeJobs::ActivateTheftAlertJob.perform_async(@payment.promoted_alert.id)
      end
    end

    def create
      theft_alert_plan = TheftAlertPlan.find(params[:theft_alert_plan_id])
      promoted_alert = PromotedAlert.create!(
        stolen_record: @bike.current_stolen_record,
        theft_alert_plan: theft_alert_plan,
        user: current_user
      )
      @payment = Payment.new(create_parameters(promoted_alert))
      @payment.stripe_checkout_session(item_name: product_description(promoted_alert))

      promoted_alert.update(payment: @payment)

      # Enqueue creation of the image with the specified image
      BikeJobs::AfterStolenRecordSaveJob.perform_async(@bike.current_stolen_record_id, false,
        params[:selected_bike_image_id])

      redirect_to @payment.stripe_checkout_session.url, allow_other_host: true
    end

    private

    def create_parameters(promoted_alert)
      {
        kind: "theft_alert",
        payment_method: "stripe",
        promoted_alert:,
        amount_cents: promoted_alert.amount_cents,
        user_id: current_user.id,
        email: current_user.email,
        currency: params[:currency] || Currency.default.name # TODO: handle this better
      }
    end

    def current_customer_data
      return {customer_email: current_user.email} if current_user.stripe_id.blank?

      {customer: current_user.stripe_id}
    end

    def product_description(promoted_alert)
      return params[:description] if params[:description].present?

      promoted_alert.theft_alert_plan&.name
    end

    def get_existing_promoted_alerts
      return unless @bike&.current_stolen_record.present?

      @promoted_alerts = @bike.current_stolen_record
        .promoted_alerts
        .includes(:theft_alert_plan)
        .creation_ordered_desc
        .references(:theft_alert_plan)
      # Only show non-user promoted_alerts to superuser
      return @promoted_alerts if current_user.superuser?

      @promoted_alerts = @promoted_alerts.where(user: current_user)
    end
  end
end
