class EmailLightspeedNotificationWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(organization_id, api_key)
    @api_key = api_key
    @organization = Organization.find(organization_id)
    AdminMailer.lightspeed_notification_email(@organization, @api_key).deliver_now
  end
end
