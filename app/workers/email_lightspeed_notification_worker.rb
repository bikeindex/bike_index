class EmailLightspeedNotificationWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'notify'
  sidekiq_options backtrace: true

  def perform(organization_id, api_key)
    @api_key = api_key
    @organization = Organization.find(organization_id)
    AdminMailer.lightspeed_notification_email(@organization, @api_key).deliver_now
  end

end