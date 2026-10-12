class MembershipsController < ApplicationController
  before_action :store_return_and_authenticate_user, only: %i[edit]

  def new
    @initial_level = params[:membership_level]
    @referral_source = referral_source_from_params
  end

  def create
    if current_user&.membership_active.present?
      return redirect_to(my_account_membership_path, notice: translation(:already_a_member))
    end

    stripe_price = StripePrice.active.where(stripe_price_parameters).first
    stripe_subscription = StripeSubscription.create_for(stripe_price:, user: current_user,
      referral_source: referral_source_from_params)
    redirect_to(stripe_subscription.stripe_checkout_session_url, allow_other_host: true)
  end

  def success
  end

  def edit
    membership = current_user.membership_active
    return redirect_to(my_account_membership_path) unless membership&.stripe_managed?

    redirect_to(membership.stripe_portal_session.url, allow_other_host: true)
  end

  private

  def stripe_price_parameters
    mem_params = params.require(:membership).permit(:level, :set_interval)

    {
      membership_level: mem_params[:level],
      interval: mem_params[:set_interval],
      currency_enum: (currency_from_params || Currency.default).slug
    }
  end

  def currency_from_params
    Currency.friendly_find(params.permit(:currency)[:currency])
  end

  def referral_source_from_params
    return params[:referral_source] if params[:referral_source].present?

    utm_param = params[:utm_campaign]
    return if utm_param.blank?

    utm_dash_split = utm_param.split("-")
    (utm_dash_split.count == 2) ? utm_dash_split.last : utm_param
  end
end
