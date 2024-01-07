class InvalidExtensionForAscendImportWorker < ApplicationWorker
  sidekiq_options queue: "notify"
  SKIP_ASCEND_EMAIL = ENV["SKIP_UNKNOWN_ASCEND_EMAIL"].present?
  NOTIFICATION_USER_ID = 377351 # Gavin email

  def perform(id)
    return if SKIP_ASCEND_EMAIL
    bulk_import = BulkImport.find(id)
    organization_id = bulk_import.organization_id
    if bulk_import.organization_id.blank?
      raise "Missing organization_id for invalid bulk_import: #{bulk_import.id}"
    end
    UpdateOrganizationPosKindWorker.new.perform(organization_id)
    organization_status = OrganizationStatus.where(organization_id: organization_id)
      .at_time(bulk_import.created_at).first

    notification = Notification.invalid_extension_for_ascend_import
      .find_by(notifiable: organization_status)
    notification ||= Notification.create(notifiable: organization_status,
      kind: :invalid_extension_for_ascend_import, user_id: NOTIFICATION_USER_ID)

    return true if notification.email_success?

    AdminMailer.invalid_extension_for_ascend_import(notification).deliver_now
    notification.update!(delivery_status: "email_success")
  end
end
