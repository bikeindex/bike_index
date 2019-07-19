class EmailNoAdminsNotificationWorker < ApplicationWorker

  sidekiq_options queue: "notify"

  def perform(organization_id)
    @organization = Organization.find(organization_id)
    AdminMailer.no_admins_notification_email(@organization).deliver_now
  end
end
