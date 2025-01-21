class PaymentsController < ApplicationController
  layout "payments_layout"

  def new
  end

  def apple_verification
    render layout: false
  end

  def success
    @payment = if params[:session_id].present?
      Payment.where(stripe_id: params[:session_id]).first
    end

    @payment&.user_id ||= current_user&.id # Stupid, only happens in testing, but whateves
    @payment&.update_from_stripe_session
  end

  def create
    if permitted_create_parameters[:amount_cents].blank?
      flash[:notice] = "Please enter an amount"
      redirect_back(fallback_location: new_payment_path) && return
    end
    @payment = Payment.new(permitted_create_parameters)
    stripe_session = Stripe::Checkout::Session.create(@payment.stripe_session_hash)

    @payment.update(stripe_id: stripe_session.id)
    redirect_to stripe_session.url
  end

  private

  def permitted_create_parameters
    params.require(:payment)
      .permit(:kind, :amount_cents, :email, :currency, :referral_source)
      .merge(user_id: current_user&.id, stripe_kind: "stripe_session")
  end
end
