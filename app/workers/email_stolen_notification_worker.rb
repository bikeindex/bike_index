class EmailStolenNotificationWorker
  include Sidekiq::Worker
  sidekiq_options queue: "notify", backtrace: true

  def perform(stolen_notification_id)
    stolen_notification = StolenNotification.find(stolen_notification_id)
    if stolen_notification.permitted_send?
      CustomerMailer.stolen_notification_email(stolen_notification).deliver_now
    else
      AdminMailer.blocked_stolen_notification_email(stolen_notification).deliver_now
    end
  end
end
