class ProcessParkingNotificationWorker < ApplicationWorker
  sidekiq_options queue: "notify"

  def perform(parking_notification_id)
    parking_notification = ParkingNotification.find(parking_notification_id)

    if parking_notification.impound_notification? && parking_notification.impound_record_id.blank?
      impound_record = ImpoundRecord.create!(bike_id: parking_notification.bike_id,
                                             user_id: parking_notification.user_id,
                                             organization_id: parking_notification.organization_id)
      parking_notification.update_attributes(impound_record_id: impound_record.id)
    end

    # If there are any records that should be associated with this record but aren't, associate them!
    if parking_notification.active?
      associated_record_ids = parking_notification.associated_notifications_including_self.pluck(:id)
      should_associate_records = ParkingNotification.active.where(organization_id: parking_notification.organization_id, bike_id: parking_notification.bike_id)
                                                    .where.not(id: associated_record_ids)
      if should_associate_records.any?
        all_records = ParkingNotification.where(id: should_associate_records.pluck(:id) + associated_record_ids)
        minimum_id = all_records.minimum(:id)
        all_records.where.not(id: minimum_id).update_all(initial_record_id: minimum_id)
        parking_notification.reload
      end
    end

    # Update all of them!
    parking_notification.associated_notifications.each do |pn|
      pn.impound_record_id = impound_record.id if impound_record.present?
      pn.retrieved_at = parking_notification.retrieved_at if parking_notification.retrieved_at.present?
      pn.update_attributes(updated_at: Time.current)
    end

    return true unless parking_notification.send_email? && parking_notification.delivery_status.blank?
    OrganizedMailer.parking_notification(parking_notification).deliver_now
    parking_notification.update_attribute :delivery_status, "email_success" # I'm not sure how to make this more representative
  end
end
