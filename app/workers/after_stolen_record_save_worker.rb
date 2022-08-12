# This will replace WebhookRunner - which is brittle and not flexible enough for what I'm looking for now
# I need to refactor that, but I don't want to right now because I don't want to break existing stuff yet

class AfterStolenRecordSaveWorker < ApplicationWorker
  sidekiq_options retry: false

  def perform(stolen_record_id)
    stolen_record = StolenRecord.unscoped.find_by_id(stolen_record_id)
    return if stolen_record.blank?
    stolen_record.remove_outdated_alert_images
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
  end
end
