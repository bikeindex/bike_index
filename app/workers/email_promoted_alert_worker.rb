class EmailPromotedAlertWorker
  include Sidekiq::Worker

  def perform(theft_alert_id)
    theft_alert = TheftAlert.find(theft_alert_id)
    CustomerMailer.promoted_alert_email(theft_alert).deliver_now
  end
end
