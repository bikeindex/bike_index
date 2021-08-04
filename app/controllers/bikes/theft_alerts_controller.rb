class Bikes::TheftAlertsController < Bikes::BaseController
  before_action :get_existing_theft_alerts, except: [:create]

  def new
    return unless setup_edit_template("alert")

    bike_image = PublicImage.find_by(id: params[:selected_bike_image_id])
    @bike.current_stolen_record.generate_alert_image(bike_image: bike_image)

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

    @payment&.update_from_stripe_session
  end

  def create
    theft_alert_plan = TheftAlertPlan.find(params[:theft_alert_plan_id])
    theft_alert = TheftAlert.create!(
      stolen_record: @bike.current_stolen_record,
      theft_alert_plan: theft_alert_plan,
      user: current_user
    )
    @payment = Payment.new(create_parameters(theft_alert))

    stripe_session = Stripe::Checkout::Session.create(
      @payment.stripe_session_hash(item_name: product_description(theft_alert))
    )

    @payment.update!(stripe_id: stripe_session.id)
    theft_alert.update(payment: @payment)

    redirect_to stripe_session.url
    image_id = params[:selected_bike_image_id]
    if image_id.present? && image_id != @bike.public_images&.first&.id
      @bike.current_stolen_record&.generate_alert_image(bike_image: PublicImage.find_by_id(image_id))
    end
  end

  private

  def create_parameters(theft_alert)
    {
      kind: "theft_alert",
      payment_method: "stripe",
      stripe_kind: "stripe_session",
      theft_alert: theft_alert,
      amount_cents: theft_alert.amount_cents,
      user_id: current_user.id,
      email: current_user.email,
      currency: params[:currency] || MoneyFormater.default_currency # TODO: handle this better
    }
  end

  def current_customer_data
    return {customer_email: current_user.email} if current_user.stripe_id.blank?
    {customer: current_user.stripe_id}
  end

  def product_description(theft_alert)
    return params[:description] if params[:description].present?
    theft_alert.theft_alert_plan&.name
  end

  def get_existing_theft_alerts
    return unless @bike&.current_stolen_record.present?

    @theft_alerts = @bike.current_stolen_record
      .theft_alerts
      .includes(:theft_alert_plan)
      .creation_ordered_desc
      .where(user: current_user)
      .references(:theft_alert_plan)
  end
end
