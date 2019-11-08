class EmailTheftAlertNotificationWorker < ApplicationWorker
  sidekiq_options queue: "notify"

  def perform(theft_alert_id, notification_type = :purchased)
    theft_alert = TheftAlert.find(theft_alert_id)

    AdminMailer
      .theft_alert_notification(theft_alert, notification_type: notification_type)
      .deliver_now
  end
end
