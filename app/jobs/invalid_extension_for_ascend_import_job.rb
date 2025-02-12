class InvalidExtensionForAscendImportJob < ApplicationJob
  sidekiq_options queue: "notify"
  SKIP_ASCEND_EMAIL = ENV["SKIP_UNKNOWN_ASCEND_EMAIL"].present?
  NOTIFICATION_USER_ID = 377351 # Gavin email

  def perform(id)
    return if SKIP_ASCEND_EMAIL
    bulk_import = BulkImport.find(id)
    organization_id = bulk_import.organization_id
    return if bulk_import.organization_id.blank?
    UpdateOrganizationPosKindJob.new.perform(organization_id)
    organization_status = OrganizationStatus.where(organization_id: organization_id)
      .at_time(bulk_import.created_at).first

    notification = Notification.invalid_extension_for_ascend_import
      .find_by(notifiable: organization_status)
    notification ||= Notification.create(notifiable: organization_status,
      kind: :invalid_extension_for_ascend_import, user_id: NOTIFICATION_USER_ID)

    notification.track_email_delivery do
      AdminMailer.invalid_extension_for_ascend_import(notification).deliver_now
    end
  end
end
