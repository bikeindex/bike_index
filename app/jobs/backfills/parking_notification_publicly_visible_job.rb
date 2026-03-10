# frozen_string_literal: true

class Backfills::ParkingNotificationPubliclyVisibleJob < ApplicationJob
  sidekiq_options queue: "low_priority", retry: false

  BATCH_SIZE = 1000

  def perform(start_id = nil)
    parking_notifications = ParkingNotification.where(publicly_visible_attribute: nil)
    parking_notifications = parking_notifications.where("id >= ?", start_id) if start_id.present?
    parking_notifications = parking_notifications.order(:id).limit(BATCH_SIZE)

    return if parking_notifications.none?

    parking_notifications.each do |parking_notification|
      visible_attribute = parking_notification.hide_address ? "postal_code" : "street"
      parking_notification.update_column(:publicly_visible_attribute,
        ParkingNotification::PUBLICLY_VISIBLE_ATTRIBUTE_ENUM[visible_attribute.to_sym])
    end

    next_id = parking_notifications.last.id + 1
    if ParkingNotification.where(publicly_visible_attribute: nil).where("id >= ?", next_id).exists?
      self.class.perform_async(next_id)
    end
  end
end
