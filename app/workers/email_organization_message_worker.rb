class EmailOrganizationMessageWorker
  include Sidekiq::Worker
  sidekiq_options queue: "notify", backtrace: true

  def perform(organization_message_id)
    org_invite = OrganizationMessage.find(organization_message_id)
  end
end
