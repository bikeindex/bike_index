class UpdateTheftAlertFacebookWorker < ApplicationWorker
  def perform(theft_alert_id, force_activate: false)
    theft_alert = TheftAlert.find(theft_alert_id)
    return false unless theft_alert.facebook_data.present?
    Facebook::AdsIntegration.new.update_facebook_data(theft_alert)
  end
end
