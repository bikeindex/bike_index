class EmailOrganizationMessageWorker
  include Sidekiq::Worker
  sidekiq_options queue: "notify", backtrace: true

  def perform(organization_message_id)
    organization_message = OrganizationMessage.find(organization_message_id)
    OrganizedMailer.custom_message(organization_message).deliver_now unless organization_message.delivery_status.present?
  end
end
