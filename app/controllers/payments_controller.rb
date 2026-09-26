class PaymentsController < ApplicationController
  layout "payments_layout"

  def new
  end

  def apple_verification
    render layout: false
  end

  def success
    @payment = if params[:session_id].present?
      Payment.find_by(stripe_id: params[:session_id])
    end

    @payment&.user_id ||= current_user&.id # Stupid, only happens in testing, but whateves
    @payment&.update_from_stripe!
  end

  def create
    amount_cents = permitted_amount_cents
    if invalid_amount_cents?(amount_cents)
      flash[:notice] = "Please enter a valid amount"
      redirect_back(fallback_location: new_payment_path) && return
    end
    @payment = Payment.create(permitted_create_parameters.merge(amount_cents:))
    @payment.stripe_checkout_session

    redirect_to @payment.stripe_checkout_session.url, allow_other_host: true
  rescue Stripe::InvalidRequestError => e
    flash[:notice] = "Unable to process payment: #{e.message}"
    redirect_back(fallback_location: new_payment_path)
  end

  private

  def invalid_amount_cents?(amount_cents)
    return true if amount_cents.blank?

    !amount_cents.to_i.between?(1, 99_999_999)
  end

  # A typed amount (in dollars) wins over a checked preset - without javascript both submit
  def permitted_amount_cents
    Amountable.to_cents(params.dig(:payment, :amount).presence) || permitted_create_parameters[:amount_cents]
  end

  def permitted_create_parameters
    params.require(:payment)
      .permit(:kind, :amount_cents, :email, :currency, :referral_source)
      .merge(user_id: current_user&.id)
  end
end
