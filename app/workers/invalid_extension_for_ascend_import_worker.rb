class InvalidExtensionForAscendImportWorker < ApplicationWorker
  sidekiq_options queue: "notify"
  SKIP_ASCEND_EMAIL = ENV["SKIP_UNKNOWN_ASCEND_EMAIL"].present?

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

    Notification.create!
    AdminMailer.invalid_extension_for_ascend_import(bulk_import).deliver_now

    # notifications = user.notifications.confirmation_email.where("created_at > ?", Time.current - 1.minute)
    # # If we just sent it, don't send again
    # return false if notifications.email_success.any?
    # notification = notifications.last || Notification.create(user_id: user.id, kind: "confirmation_email")
    # CustomerMailer.confirmation_email(user).deliver_now
    # notification.update(delivery_status: "email_success") # I'm not sure how to make this more representative
  end
end
