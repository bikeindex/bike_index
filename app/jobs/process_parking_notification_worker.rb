class ProcessParkingNotificationWorker < ApplicationWorker
  sidekiq_options queue: "notify"

  def perform(parking_notification_id)
    parking_notification = ParkingNotification.find(parking_notification_id)

    if parking_notification.impound_notification? && parking_notification.impound_record_id.blank?
      impound_record = ImpoundRecord.create!(bike_id: parking_notification.bike_id,
        user_id: parking_notification.user_id,
        organization_id: parking_notification.organization_id,
        skip_update: true)
      parking_notification.resolved_at ||= Time.current
      parking_notification.update(impound_record_id: impound_record.id)
      ProcessImpoundUpdatesWorker.new.perform(impound_record.id)
    end

    # Update all of them!
    parking_notification.associated_notifications.each do |pn|
      pn.impound_record_id = impound_record.id if impound_record.present?
      pn.update(updated_at: Time.current, skip_update: true)
    end

    # If there are any notifications from the same period, resolve them - even if they aren't associated
    if parking_notification.reload.resolved?
      parking_notification.notifications_from_period.active.each do |notification|
        # Add a note about it though, to document it
        notes = [notification.internal_notes, "resolved by parking notification ##{parking_notification.id}"]
        notification.update(resolved_at: parking_notification.resolved_at,
          internal_notes: notes.join(", "))
      end
    end

    return true unless parking_notification.send_email? && parking_notification.delivery_status.blank?
    OrganizedMailer.parking_notification(parking_notification).deliver_now
    parking_notification.update_attribute :delivery_status, "email_success" # I'm not sure how to make this more representative
  end
end
