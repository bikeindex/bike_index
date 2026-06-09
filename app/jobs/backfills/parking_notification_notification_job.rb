# frozen_string_literal: true

module Backfills
  # Backfills a delivery_success Notification for each parking_notification that recorded a successful
  # send in the legacy delivery_status column, so the column can be dropped in a follow-up PR.
  # Only "email_success" is a reliable positive signal; nil and "bike_unregistered" are treated as unsent.
  # Creates the Notification directly — does not send email or update user_email.
  class ParkingNotificationNotificationJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform(id = nil)
      return enqueue_workers if id.blank?

      parking_notification = ParkingNotification.find(id)
      return unless parking_notification.has_attribute?(:delivery_status)
      return if parking_notification.notifications.any?
      return unless parking_notification.delivery_status == "email_success"

      Notification.create!(kind: "parking_notification",
        notifiable: parking_notification,
        bike_id: parking_notification.bike_id,
        user_id: parking_notification.bike&.user_id,
        message_channel_target: parking_notification.email,
        delivery_status: "delivery_success")
    end

    private

    def enqueue_workers
      return unless ParkingNotification.column_names.include?("delivery_status")

      ParkingNotification.where(delivery_status: "email_success")
        .find_each { |parking_notification| self.class.perform_async(parking_notification.id) }
    end
  end
end
