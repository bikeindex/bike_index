class TheftAlertPurchaseNotificationWorker < ApplicationWorker
  sidekiq_options queue: "notify"

  def perform(theft_alert_id, recovery = false)
    theft_alert = TheftAlert.find(theft_alert_id)

    AdminMailer
      .theft_alert_notification(theft_alert, notification_type: :recovered)
      .deliver_now
  end
end
