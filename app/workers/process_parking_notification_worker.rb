class ProcessParkingNotificationWorker < ApplicationWorker
  sidekiq_options queue: "notify"

  def perform(parking_notification_id)
    parking_notification = ParkingNotification.find(parking_notification_id)

    if parking_notification.impounded? && parking_notification.impound_record.blank?
      impound_record = ImpoundRecord.create(bike_id: parking_notification.bike_id,
                                            user_id: parking_notification.user_id,
                                            organization_id: parking_notification.organization_id)
      parking_notification.update_attributes(impound_record_id: impound_record.id)
    end

    # Update all of them!
    parking_notification.associated_notifications.each do |pn|
      pn.update_attributes(updated_at: Time.current,
                           impound_record_id: parking_notification.impound_record_id)
    end

    return true unless parking_notification.send_email? && parking_notification.delivery_status.blank?
    OrganizedMailer.parking_notification(parking_notification).deliver_now
    parking_notification.update_attribute :delivery_status, "email_success" # I'm not sure how to make this more representative
  end
end
