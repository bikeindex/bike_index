class StolenBike::UpdatePromotedAlertFacebookJob < ScheduledJob
  prepend ScheduledJobRecorder
  sidekiq_options queue: "low_priority", retry: 3 # It will retry because of scheduling

  def self.frequency
    34.minutes
  end

  def perform(promoted_alert_id = nil)
    return enqueue_workers if promoted_alert_id.blank?

    promoted_alert = PromotedAlert.find(promoted_alert_id)
    # If the ad_id is blank, we need to activate the ad
    if promoted_alert.facebook_data&.dig("ad_id").blank?
      return StolenBike::ActivatePromotedAlertJob.perform_async(promoted_alert_id)
    end
    Facebook::AdsIntegration.new.update_facebook_data(promoted_alert)

    return true unless promoted_alert.notify? &&
      promoted_alert.notifications.promoted_alert_posted.none?
    # Perform inline rather than re-querying for objects
    EmailPromotedAlertNotificationJob.new.perform(promoted_alert_id, "promoted_alert_posted", promoted_alert)
  end

  def enqueue_workers
    PromotedAlert.should_update_facebook.where(facebook_updated_at: nil).pluck(:id)
      .each { |i| self.class.perform_async(i) }

    # Try to avoid overrunning our rate limits
    PromotedAlert.failed_to_activate.pluck(:id)
      .each { |i| self.class.perform_in(2.minutes, i) }

    PromotedAlert.should_update_facebook.where.not(facebook_updated_at: nil)
      .order(:facebook_updated_at).limit(20).pluck(:id)
      .each_with_index { |i, inx| self.class.perform_in(3.minutes + inx.minutes, i) }
  end
end
