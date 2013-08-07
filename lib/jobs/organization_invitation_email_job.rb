class OrganizationInvitationEmailJob
  @queue = "email"

  def self.perform(org_invite_id)
    org_invite = OrganizationInvitation.find(org_invite_id)
    CustomerMailer.organization_invitation_email(org_invite).deliver
  end
end
