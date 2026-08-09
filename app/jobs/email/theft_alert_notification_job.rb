# frozen_string_literal: true

module Email
  class TheftAlertNotificationJob < ApplicationJob
    sidekiq_options queue: "notify", retry: 3

    def perform(promoted_alert_id, kind, promoted_alert = nil)
      promoted_alert ||= PromotedAlert.find(promoted_alert_id)

      notification = promoted_alert.notifications.where(kind: kind).first
      notification ||= Notification.create(user: promoted_alert.user,
        kind: kind,
        message_channel: "email",
        notifiable: promoted_alert,
        bike: promoted_alert.bike)

      notification.track_email_delivery do
        if kind == "theft_alert_recovered"
          AdminMailer.theft_alert_notification(promoted_alert, notification_type: kind)
            .deliver_now
        else
          CustomerMailer.theft_alert_email(promoted_alert, notification).deliver_now
        end
      end
    end
  end
end
