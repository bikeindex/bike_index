class TheftAlertPurchaseNotificationWorker < ApplicationWorker
  sidekiq_options queue: "notify"

  def perform(theft_alert_id, recovery = false)
    theft_alert = TheftAlert.find(theft_alert_id)

    AdminMailer
      .theft_alert_purchased(theft_alert, notify_of_recovery: recovery)
      .deliver_now
  end
end
