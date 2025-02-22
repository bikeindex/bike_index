class MembershipsController < ApplicationController
  before_action :enable_importmaps

  layout "payments_layout"

  def new
  end

  def create
    stripe_price = StripePrice.where(stripe_price_parameters).first
    stripe_subscription = StripeSubscription.create_for(stripe_price:, user: current_user)
    redirect_to(stripe_subscription.stripe_checkout_session_url, allow_other_host: true)
  end

  def success
    render layout: "application"
  end

  private

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
