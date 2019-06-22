class TheftAlertPurchaseNotificationWorker
  include Sidekiq::Worker
  sidekiq_options queue: "notify"
  sidekiq_options backtrace: true

  def perform(theft_alert_id)
    theft_alert = TheftAlert.find(theft_alert_id)
    AdminMailer.theft_alert_purchased(theft_alert).deliver_now
  end
end
