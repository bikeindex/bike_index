class EmailOrganizationInvitationWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'notify'
  sidekiq_options backtrace: true

  def perform(org_invite_id)
    org_invite = OrganizationInvitation.find(org_invite_id)
    OrganizedMailer.organization_invitation(org_invite).deliver_now
  end
end
