# frozen_string_literal: true

module Backfills
  # Backfills a Notification for each emailable parking_notification, recording the legacy delivery
  # outcome so the delivery_status column can be dropped in a follow-up PR. "email_success" becomes a
  # delivery_success Notification; anything else becomes delivery_failure with a marker delivery_error.
  # Creates the Notification directly — does not send email or update user_email.
  class ParkingNotificationNotificationJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def self.enqueue_workers(end_time = Time.current)
      ParkingNotification.send_email.where("parking_notifications.created_at < ?", end_time)
        .pluck(:id).each { |id| perform_async(id) }
    end

    def perform(id)
      parking_notification = ParkingNotification.find(id)
      return if parking_notification.notifications.any?
      return unless parking_notification.send_email?

      success = parking_notification.delivery_status == "email_success"
      Notification.create!(kind: "parking_notification",
        notifiable: parking_notification,
        bike_id: parking_notification.bike_id,
        user_id: parking_notification.bike&.user_id,
        message_channel_target: parking_notification.email,
        delivery_status: success ? "delivery_success" : "delivery_failure",
        delivery_error: success ? nil : ParkingNotification::PRE_TRACKING_ERROR)
    end
  end
end
