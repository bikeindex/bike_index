class AfterStolenRecordSaveJob < ApplicationJob
  sidekiq_options retry: false

  def perform(stolen_record_id, remove_alert_image = false)
    stolen_record = StolenRecord.unscoped.find_by_id(stolen_record_id)
    return if stolen_record.blank?
    stolen_record.skip_update = true
    # If the bike has been recovered (or alert_location_changed - which causes remove_alert_image to be true)
    if remove_alert_image || stolen_record.bike.blank? || !stolen_record.bike.status_stolen? || stolen_record.recovered?
      stolen_record.alert_image&.destroy
    end

    stolen_record.theft_alerts.each { |t| t.update(updated_at: Time.current) }
    if stolen_record.current
      StolenRecord.unscoped.where(bike_id: stolen_record.bike_id).where.not(id: stolen_record.id)
        .each { |s| s.update(current: false, skip_update: true) }
    end

    if stolen_record.organization_stolen_message.blank?
      stolen_message = OrganizationStolenMessage.for_stolen_record(stolen_record)
      if stolen_message.present?
        stolen_record.update(organization_stolen_message_id: stolen_message.id, skip_update: true)
      end
    end
    stolen_record.current_alert_image # Generate alert image
    stolen_record.find_or_create_recovery_link_token
  end
end
