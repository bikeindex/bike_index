class UserAlertsController < ApplicationController
  before_action :authenticate_user_for_user_alerts_controller

  def update
    @user_alert = current_user.user_alerts.find_by_id(params[:id])
    if @user_alert.present?
      if params[:alert_action] == "dismiss"
        if @user_alert.dismissable?
          @user_alert.dismiss! if @user_alert.active?
        else
          flash[:error] = "We're sorry, you can't hide that alert"
        end
      elsif Binxtils::InputNormalizer.boolean(params[:add_bike_organization])
        add_bike_organization
      else
        flash[:error] = "Unknown alert action!"
      end
    else
      flash[:error] = "Unable to find that alert"
    end
    redirect_back(fallback_location: user_root_url)
  end

  private

  def authenticate_user_for_user_alerts_controller
    authenticate_user(translation_key: :you_have_to_log_in, flash_type: :info)
  end

  # Probably only should be called for "unassigned_bike_org"
  def add_bike_organization
    if @user_alert.user.authorized?(@user_alert.bike)
      bike_organization = BikeOrganization.find_or_create_by(bike_id: @user_alert.bike_id,
        organization_id: @user_alert.organization_id)
      @user_alert.resolve! if bike_organization.valid?
      ::Callbacks::AfterUserChangeJob.perform_async(@user_alert.user_id)
    else
      flash[:error] = "You don't have permission to edit that bike"
    end
  end
end
