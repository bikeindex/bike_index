class EmailStolenNotificationWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(stolen_notification_id, force_send = false)
    stolen_notification = StolenNotification.find(stolen_notification_id)
    notification = if force_send
      Notification.create(notifiable: stolen_notification)
    else
      Notification.find_or_create_by(notifiable: stolen_notification)
    end

    notification.kind = if force_send || stolen_notification.permitted_send?
      "stolen_notification_sent"
    elsif stolen_notification.bike.present?
      "stolen_notification_blocked"
    else
      return # Bike is deleted or something
    end

    notification.track_email_delivery do
      if notification.kind == "stolen_notification_sent"
        CustomerMailer.stolen_notification_email(stolen_notification).deliver_now
      else
        AdminMailer.blocked_stolen_notification_email(stolen_notification).deliver_now
      end
    end
  end
end
