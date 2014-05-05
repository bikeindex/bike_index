class LightspeedNotificationEmailJob
  @queue = "email"

  def self.perform(organization_id, api_key)
    @api_key = api_key
    @organization = Organization.find(organization_id)
    AdminMailer.lightspeed_notification_email(@organization, @api_key).deliver
  end

end