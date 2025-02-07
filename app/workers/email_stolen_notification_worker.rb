class EmailStolenNotificationWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(stolen_notification_id, force_send = false)
    stolen_notification = StolenNotification.find(stolen_notification_id)
    notification = if force_send
      Notification.create(notifiable: stolen_notification)
    else
      Notification.find_or_create_by(notifiable: stolen_notification)
    end

    return true if notification.delivered?
    if force_send || stolen_notification.permitted_send?
      notification.kind = "stolen_notification_sent"
      CustomerMailer.stolen_notification_email(stolen_notification).deliver_now
    elsif stolen_notification.bike.present?
      notification.kind = "stolen_notification_blocked"
      AdminMailer.blocked_stolen_notification_email(stolen_notification).deliver_now
    end
    notification.update(delivery_status_str: "email_success") if notification.kind.present?
  end
end
