class MembershipsController < ApplicationController
  before_action :enable_importmaps
  before_action :store_return_and_authenticate_user, only: %i[edit]

  layout "payments_layout"

  def new
    if current_user&.membership_active.present?
      redirect_to edit_membership_path
    end
  end

  def create
    stripe_price = StripePrice.where(stripe_price_parameters).first
    stripe_subscription = StripeSubscription.create_for(stripe_price:, user: current_user)
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
    mem_params = params.require(:membership).permit(:kind, :set_interval)
    currency_enum = (currency_from_params || Currency.default).slug

    {
      membership_kind: mem_params[:kind],
      interval: mem_params[:set_interval],
      currency_enum:
    }
  end

  def currency_from_params
    Currency.friendly_find(params.permit(:currency)[:currency])
  end
end
