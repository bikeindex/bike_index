class UpdateTheftAlertFacebookWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(theft_alert_id)
    theft_alert = TheftAlert.find(theft_alert_id)
    return false unless theft_alert.facebook_data&.dig("ad_id").present?
    Facebook::AdsIntegration.new.update_facebook_data(theft_alert)
    return true unless theft_alert.notify? &&
      theft_alert.notifications.theft_alert_posted.none?

    # Perform inline rather than re-querying for objects
    EmailTheftAlertNotificationWorker.new.perform(theft_alert_id, "theft_alert_posted", theft_alert)
  end
end
