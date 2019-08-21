class EmailPromotedAlertWorker < ApplicationWorker

  sidekiq_options queue: "notify"

  def perform(theft_alert_id)
    theft_alert = TheftAlert.find(theft_alert_id)
    CustomerMailer.promoted_alert_email(theft_alert).deliver_now
  end
end
