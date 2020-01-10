class EmailOrganizationMessageWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(organization_message_id)
    organization_message = OrganizationMessage.find(organization_message_id)
    return true if organization_message.delivery_status.present?
    OrganizedMailer.custom_message(organization_message).deliver_now
    organization_message.update_attribute :delivery_status, "success" # I'm not sure how to make this actually representative
  end
end
