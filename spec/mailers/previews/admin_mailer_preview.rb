# Preview emails at /rails/mailers/admin_mailer
class AdminMailerPreview < ActionMailer::Preview
  def feedback_notification_email
    feedback = Feedback.last
    AdminMailer.feedback_notification_email(feedback)
  end

  def no_admins_notification_email
    organization = Organization.last
    AdminMailer.no_admins_notification_email(organization)
  end

  def blocked_stolen_notification_email
    stolen_notification = StolenNotification.last
    AdminMailer.blocked_stolen_notification_email(stolen_notification)
  end

  def lightspeed_notification_email
    organization = Organization.last
    AdminMailer.lightspeed_notification_email(organization, 'asdfasdf')
  end

  def unknown_organization_for_ascend_import
    bulk_import = BulkImport.ascend.last || BulkImport.last
    AdminMailer.unknown_organization_for_ascend_import(bulk_import)
  end
end
