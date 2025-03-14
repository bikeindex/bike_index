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
    if invalid_amount_cents?(permitted_create_parameters[:amount_cents])
      flash[:notice] = "Please enter a valid amount"
      redirect_back(fallback_location: new_payment_path) && return
    end
    @payment = Payment.create(permitted_create_parameters)
    @payment.stripe_checkout_session

    redirect_to @payment.stripe_checkout_session.url, allow_other_host: true
  end

  private

  def invalid_amount_cents?(amount_cents)
    return true if amount_cents.blank?

    !amount_cents.to_i.between?(1, 99_999_999)
  end

  def permitted_create_parameters
    params.require(:payment)
      .permit(:kind, :amount_cents, :email, :currency, :referral_source)
      .merge(user_id: current_user&.id)
  end
end
