class StolenBike::UpdateTheftAlertFacebookJob < ScheduledJob
  prepend ScheduledJobRecorder
  sidekiq_options queue: "low_priority", retry: 3 # It will retry because of scheduling

  def self.frequency
    34.minutes
  end

  def perform(theft_alert_id = nil)
    return enqueue_workers if theft_alert_id.blank?

    theft_alert = TheftAlert.find(theft_alert_id)
    # If the ad_id is blank, we need to activate the ad
    if theft_alert.facebook_data&.dig("ad_id").blank? || theft_alert.failed_to_activate?
      return StolenBike::ActivateTheftAlertJob.perform_async(theft_alert_id)
    end
    Facebook::AdsIntegration.new.update_facebook_data(theft_alert)

    return true unless theft_alert.notify? &&
      theft_alert.notifications.theft_alert_posted.none?
    # Perform inline rather than re-querying for objects
    Email::TheftAlertNotificationJob.new.perform(theft_alert_id, "theft_alert_posted", theft_alert)
  end

  def enqueue_workers
    TheftAlert.should_update_facebook.where(facebook_updated_at: nil).pluck(:id)
      .each { |i| self.class.perform_async(i) }

    # Try to avoid overrunning our rate limits
    TheftAlert.failed_to_activate.pluck(:id)
      .each { |i| self.class.perform_in(2.minutes, i) }

    TheftAlert.should_update_facebook.where.not(facebook_updated_at: nil)
      .order(:facebook_updated_at).limit(20).pluck(:id)
      .each_with_index { |i, inx| self.class.perform_in(3.minutes + inx.minutes, i) }
  end
end
