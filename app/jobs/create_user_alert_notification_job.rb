class CreateUserAlertNotificationJob < ScheduledJob
  prepend ScheduledJobRecorder

  def self.frequency
    33.minutes
  end

  def perform(user_alert_id = nil)
    return enqueue_workers if user_alert_id.blank?

    user_alert = UserAlert.find(user_alert_id)
    return unless user_alert.create_notification?

    notification = Notification.find_or_create_by(notifiable: user_alert,
      kind: "user_alert_#{user_alert.kind}")

    notification.track_email_delivery do
      CustomerMailer.user_alert_email(user_alert).deliver_now
    end
  end

  def enqueue_workers
    UserAlert.create_notification.pluck(:id).each { |i| CreateUserAlertNotificationJob.perform_async(i) }
  end
end
