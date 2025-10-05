class StolenBike::AfterStolenRecordSaveJob < ApplicationJob
  sidekiq_options retry: false

  def perform(stolen_record_id, force_regenerate_images = false, public_image_id = nil)
    stolen_record = StolenRecord.unscoped.find_by_id(stolen_record_id)
    return if stolen_record.blank?

    stolen_record.skip_update = true

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
    stolen_record.find_or_create_recovery_link_token

    Images::StolenProcessor.update_alert_images(stolen_record,
      force_regenerate: force_regenerate_images,
      public_image_id:)
  end
end
