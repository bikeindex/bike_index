# frozen_string_literal: true

module Backfills
  # Backfills a delivery_success Notification for each parking_notification that recorded a successful
  # send in the legacy delivery_status column, so the column can be dropped in a follow-up PR.
  # enqueue_workers selects the "email_success" rows (nil and "bike_unregistered" are treated as unsent),
  # so perform just creates the Notification — directly, without sending email or updating user_email.
  class ParkingNotificationNotificationJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform(id = nil)
      return enqueue_workers if id.blank?

      parking_notification = ParkingNotification.find(id)
      return if parking_notification.notifications.any?

      Notification.create!(kind: "parking_notification",
        notifiable: parking_notification,
        bike_id: parking_notification.bike_id,
        user_id: parking_notification.bike&.user_id,
        message_channel_target: parking_notification.email,
        delivery_status: "delivery_success")
    end

    private

    def enqueue_workers
      ParkingNotification.where(delivery_status: "email_success").pluck(:id)
        .each { |id| self.class.perform_async(id) }
    end
  end
end
