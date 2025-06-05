class MembershipsController < ApplicationController
  before_action :store_return_and_authenticate_user, only: %i[edit]

  layout "payments_layout"

  def new
    if current_user&.membership_active.present?
      redirect_to edit_membership_path
    end
    @referral_source = referral_source_from_params
  end

  def create
    stripe_price = StripePrice.active.where(stripe_price_parameters).first
    stripe_subscription = StripeSubscription.create_for(stripe_price:, user: current_user,
      referral_source: referral_source_from_params)
    redirect_to(stripe_subscription.stripe_checkout_session_url, allow_other_host: true)
  end

  def success
    render layout: "application"
  end

  def edit
    if current_user.membership_active.present?
      if current_user.membership_active.admin_managed?
        flash[:notice] = translation(:free_membership)
        redirect_to my_account_path
      else
        redirect_to(current_user.membership_active.stripe_portal_session.url, allow_other_host: true)
      end
    else
      flash[:notice] = translation(:no_active_membership)
      redirect_to new_membership_path
    end
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
