class NoAdminsNotificationJob
  @queue = "email"

  def self.perform(organization_id)
    @organization = Organization.find(organization_id)
    AdminMailer.no_admins_notification_email(@organization).deliver
  end

end