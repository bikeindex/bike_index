class EmailOrganizationMessageWorker
  include Sidekiq::Worker
  sidekiq_options queue: "notify", backtrace: true

  def perform(organization_message_id)
    organization_message = OrganizationMessage.find(organization_message_id)
    return true if organization_message.delivery_status.present?
    result = OrganizedMailer.custom_message(organization_message).deliver_now
    organization_message.update_attribute :delivery_status, result.to_s # I'm not sure what this looks like, so just try it
  end
end
