class MembershipsController < ApplicationController
  before_action :authenticate_user_for_my_accounts_controller

  layout "payments_layout"

  def new
  end

  # def success
  #   @payment = if params[:session_id].present?
  #     Payment.where(stripe_id: params[:session_id]).first
  #   end

  #   @payment&.user_id ||= current_user&.id # Stupid, only happens in testing, but whateves
  #   @payment&.update_from_stripe_session
  # end

  # def create
  #   if invalid_amount_cents?(permitted_create_parameters[:amount_cents])
  #     flash[:notice] = "Please enter a valid amount"
  #     redirect_back(fallback_location: new_payment_path) && return
  #   end
  #   @payment = Payment.new(permitted_create_parameters)
  #   stripe_session = Stripe::Checkout::Session.create(@payment.stripe_session_hash)

  #   @payment.update(stripe_id: stripe_session.id)
  #   redirect_to stripe_session.url, allow_other_host: true
  # end

  private

  def invalid_amount_cents?(amount_cents)
    return true if amount_cents.blank?

    !amount_cents.to_i.between?(1, 99_999_999)
  end

  def permitted_create_parameters
    params.require(:membership)
      .permit(:kind, :currency_enum, :interval)
      .merge(user_id: current_user&.id)
  end
end
