class Bikes::TheftAlertsController < Bikes::BaseController
  def new
    if setup_edit_template("alert")
      bike_image = PublicImage.find_by(id: params[:selected_bike_image_id])
      @bike.current_stolen_record.generate_alert_image(bike_image: bike_image)

      @theft_alert_plans = TheftAlertPlan.active.price_ordered_asc.in_language(I18n.locale)
      @selected_theft_alert_plan =
        @theft_alert_plans.find_by(id: params[:selected_plan_id]) ||
        @theft_alert_plans.order(:amount_cents).second

      @theft_alerts = @bike.current_stolen_record
        .theft_alerts
        .includes(:theft_alert_plan)
        .creation_ordered_desc
        .where(user: current_user)
        .references(:theft_alert_plan)
    end
  end

  def update
  end

  def create
    theft_alert_plan = TheftAlertPlan.find(params[:theft_alert_plan_id])
    theft_alert = TheftAlert.create!(
      stolen_record: @bike.current_stolen_record,
      theft_alert_plan: theft_alert_plan,
      user: current_user
    )
    @payment = Payment.new(permitted_create_parameters(theft_alert))

    stripe_session = Stripe::Checkout::Session.create(current_customer_data.merge(
      submit_type: "pay",
      payment_method_types: ["card"],
      line_items: [{
        price_data: {
          unit_amount: @payment.amount_cents,
          currency: @payment.currency,
          product_data: {
            name: product_description(theft_alert),
            images: ["https://files.bikeindex.org/uploads/Pu/151203/reg_hance.jpg"]
          }
        },
        quantity: 1
      }],
      mode: "payment",
      success_url: @payment.stripe_success_url,
      cancel_url: @payment.stripe_cancel_url
    ))

    @payment.update!(stripe_id: stripe_session.id)
    theft_alert.update(payment: @payment)
    redirect_to stripe_session.url
  end

  private

  def permitted_create_parameters(theft_alert)
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
end
