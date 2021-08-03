class TheftAlertsController < ApplicationController
  before_action :ensure_user_allowed_to_create_theft_alert

  def create
    theft_alert_plan = TheftAlertPlan.find(params[:selected_plan_id])
    theft_alert = TheftAlert.create!(
      stolen_record: @bike.current_stolen_record,
      theft_alert_plan: theft_alert_plan,
      user: current_user
    )

    # payment = TheftAlertPaymentCreator.new!(
    #   user: current_user,
    #   stripe_email: params[:stripe_email],
    #   stripe_token: params[:stripe_token],
    #   stripe_amount: params[:stripe_amount],
    #   stripe_currency: params[:stripe_currency]
    # )

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
    @payment.update(stripe_id: stripe_session.id)
    theft_alert.update(payment: @payment)

    redirect_to stripe_session.url

  #   # theft_alert.update(payment: payment)
  # rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
  #   flash[:error] = translation(:unable_to_process_order)
  #   redirect_to edit_bike_url(@bike, params: {edit_template: :alert})
  # rescue Stripe::CardError
  #   flash[:error] = translation(:order_is_pending)
  #   redirect_to edit_bike_url(@bike, params: {edit_template: :alert})
  # else
  #   # Previously we sent an email about successful promoted alerts, no longer doing that
  #   redirect_to edit_bike_url(@bike, params: {edit_template: :alert_purchase_confirmation})
  end

  private

  def ensure_user_allowed_to_create_theft_alert
    @bike = Bike.find_by(id: params[:bike_id])
    @current_ownership = @bike&.current_ownership
    return true if @bike&.authorize_and_claim_for_user(current_user)

    flash[:error] = translation(:unauthorized)
    redirect_to(bikes_url) && return
  end

  def permitted_create_parameters(theft_alert)
    {
      payment_method: "stripe",
      user_id: current_user.id,
      email: current_user.email,
      kind: "theft_alert",
      stripe_kind: "stripe_session",
      amount_cents: theft_alert.amount_cents,
      currency: params[:currency]
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
