class MembershipsController < ApplicationController
  before_action :enable_importmaps

  layout "payments_layout"

  def new
  end

  def create
    pp stripe_price_parameters
    stripe_price = StripePrice.where(stripe_price_parameters).first
    pp stripe_price, "----"
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

  def stripe_price_parameters
    mem_params = params.require(:membership).permit(:kind, :set_interval)
    currency_enum = (Currency.new(params.permit(:currency)[:currency]) || Currency.default).slug

    {
      membership_kind: mem_params[:kind],
      interval: mem_params[:set_interval],
      currency_enum:
    }
  end
end
