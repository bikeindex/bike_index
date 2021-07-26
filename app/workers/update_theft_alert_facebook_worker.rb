class UpdateTheftAlertFacebookWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 5 # retry is managed internally

  def perform(theft_alert_id)
    theft_alert = TheftAlert.find(theft_alert_id)
    # If the ad_id is blank, we need to activate the ad
    if theft_alert.facebook_data&.dig("ad_id").blank?
      return ActivateTheftAlertWorker.perform_async(theft_alert_id)
    end
    i = Facebook::AdsIntegration.new.update_facebook_data(theft_alert)
    return true unless theft_alert.notify? &&
      theft_alert.notifications.theft_alert_posted.none?

    # Temporary pause on notification
    unless theft_alert.facebook_data&.dig("no_notify")
      theft_alert.update(facebook_data: theft_alert.facebook_data.merge(no_notify: true))
    end
    # Perform inline rather than re-querying for objects
    # EmailTheftAlertNotificationWorker.new.perform(theft_alert_id, "theft_alert_posted", theft_alert)
  end
end
