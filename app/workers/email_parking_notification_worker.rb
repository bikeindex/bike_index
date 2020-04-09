class EmailParkingNotificationWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(parking_notification_id)
    parking_notification = ParkingNotification.find(parking_notification_id)
    return true if parking_notification.delivery_status.present?
    if parking_notification.unregistered_bike
      parking_notification.update_attribute :delivery_status, "unregistered_bike"
    else
      OrganizedMailer.parking_notification(parking_notification).deliver_now
      parking_notification.update_attribute :delivery_status, "email_success" # I'm not sure how to make this more representative
    end
  end
end
