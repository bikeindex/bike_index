class UserAlertsController < ApplicationController
  before_action :authenticate_user_for_user_alerts_controller

  def update
    user_alert = current_user.user_alerts.find_by_id(params[:id])
    if user_alert.present?
      if params[:alert_action] == "dismiss"
        if user_alert.dismissable?
          user_alert.dismiss! if user_alert.active?
        else
          flash[:error] = "We're sorry, you can't hide that alert"
        end
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
end
