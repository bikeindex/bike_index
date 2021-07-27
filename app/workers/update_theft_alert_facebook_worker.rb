class UpdateTheftAlertFacebookWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder
  sidekiq_options queue: "low_priority", retry: 4 # It will retry because of scheduling

  def self.frequency
    62.minutes
  end

  def perform(theft_alert_id = nil)
    return enqueue_workers if theft_alert_id.blank?

    theft_alert = TheftAlert.find(theft_alert_id)
    # If the ad_id is blank, we need to activate the ad
    if theft_alert.facebook_data&.dig("ad_id").blank?
      return ActivateTheftAlertWorker.perform_async(theft_alert_id)
    end
    i = Facebook::AdsIntegration.new.update_facebook_data(theft_alert)
    return true unless theft_alert.notify? &&
      theft_alert.notifications.theft_alert_posted.none?

    # Temporary pause on notification - set no notify so we don't notify when we turn notifications back on
    unless theft_alert.facebook_data&.dig("no_notify")
      theft_alert.update(facebook_data: theft_alert.facebook_data.merge(no_notify: true))
    end
    # Perform inline rather than re-querying for objects
    # EmailTheftAlertNotificationWorker.new.perform(theft_alert_id, "theft_alert_posted", theft_alert)
  end

  def enqueue_workers
    TheftAlert.should_update_facebook.where(facebook_updated_at: nil).pluck(:id)
      .each { |i| UpdateTheftAlertFacebookWorker.perform_async(i) }
    # Try to avoid overrunning our rate limits
    TheftAlert.should_update_facebook.where.not(facebook_updated_at: nil).order(:facebook_updated_at).limit(10)
      .each { |i| UpdateTheftAlertFacebookWorker.perform_async(i) }
  end
end
