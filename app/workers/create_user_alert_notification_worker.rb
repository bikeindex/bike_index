class CreateUserAlertNotificationWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    33.minutes
  end

  def perform(user_alert_id = nil)
    return enqueue_workers if user_alert_id.blank?
    user_alert = UserAlert.find(user_alert_id)
    return unless user_alert.create_notification?

    notification = Notification.create(user_id: user_alert.user_id,
                        bike_id: user_alert.bike_id,
                        kind: "user_alert_#{user_alert.kind}")
    CustomerMailer.donation_email(notification_kind, payment).deliver_now
    notification.update(delivery_status: "email_success")
    # Assign afterward so that it the alert is notification found
    user_alert.update(notification_id: notification.id)
  end

  def enqueue_workers
    UserAlert.create_notification.pluck(:id).each { |i| CreateUserAlertNotificationWorker.perform_async(i) }
  end
end
