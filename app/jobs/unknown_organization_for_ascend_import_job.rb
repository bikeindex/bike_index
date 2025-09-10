class UnknownOrganizationForAscendImportJob < ApplicationJob
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
      user_id: InvalidExtensionForAscendImportJob::NOTIFICATION_USER_ID)

    notification.track_email_delivery do
      AdminMailer.unknown_organization_for_ascend_import(notification).deliver_now
    end
  end
end
