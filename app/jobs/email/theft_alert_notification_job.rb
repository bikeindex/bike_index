# frozen_string_literal: true

class Email::TheftAlertNotificationJob < ApplicationJob
  sidekiq_options queue: "notify", retry: 3

  def perform(theft_alert_id, kind, theft_alert = nil)
    theft_alert ||= TheftAlert.find(theft_alert_id)

    notification = theft_alert.notifications.where(kind: kind).first
    notification ||= Notification.create(user: theft_alert.user,
      kind: kind,
      message_channel: "email",
      notifiable: theft_alert,
      bike: theft_alert.bike)

    notification.track_email_delivery do
      if kind == "theft_alert_recovered"
        AdminMailer.theft_alert_notification(theft_alert, notification_type: kind)
          .deliver_now
      else
        CustomerMailer.theft_alert_email(theft_alert, notification).deliver_now
      end
    end
  end
end
