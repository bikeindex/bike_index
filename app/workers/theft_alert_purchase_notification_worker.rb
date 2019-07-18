class TheftAlertPurchaseNotificationWorker < ApplicationWorker
  sidekiq_options queue: "notify"

  def perform(theft_alert_id)
    theft_alert = TheftAlert.find(theft_alert_id)
    AdminMailer.theft_alert_purchased(theft_alert).deliver_now
  end
end
