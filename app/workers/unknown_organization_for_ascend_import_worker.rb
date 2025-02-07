class UnknownOrganizationForAscendImportWorker < ApplicationWorker
  sidekiq_options queue: "notify"

  # enable temporarily skipping the email, because we have a bunch of errored
  SKIP_ASCEND_EMAIL = ENV["SKIP_ASCEND_EMAIL"].present?

  def perform(id)
    return if SKIP_ASCEND_EMAIL
    bulk_import = BulkImport.find(id)
    notification = Notification.unknown_organization_for_ascend
      .where(notifiable: bulk_import).first
    notification ||= Notification.create!(notifiable: bulk_import,
      kind: :unknown_organization_for_ascend,
      user_id: InvalidExtensionForAscendImportWorker::NOTIFICATION_USER_ID)

    return true if notification.email_success?

    AdminMailer.unknown_organization_for_ascend_import(notification).deliver_now
    notification.update!(delivery_status_str: "email_success")
  end
end
