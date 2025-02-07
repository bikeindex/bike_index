class CreateUserAlertNotificationWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    33.minutes
  end

  def perform(user_alert_id = nil)
    return enqueue_workers if user_alert_id.blank?

    user_alert = UserAlert.find(user_alert_id)
    return unless user_alert.create_notification?
    notification = Notification.find_or_create_by(notifiable: user_alert,
      kind: "user_alert_#{user_alert.kind}")

    CustomerMailer.user_alert_email(user_alert).deliver_now

    notification.update(delivery_status_str: "email_success")
  end

  def enqueue_workers
    UserAlert.create_notification.pluck(:id).each { |i| CreateUserAlertNotificationWorker.perform_async(i) }
  end
end
