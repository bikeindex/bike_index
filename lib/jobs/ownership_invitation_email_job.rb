class OwnershipInvitationEmailJob
  @queue = "email"

  def self.perform(ownership_id)
    ownership = Ownership.find(ownership_id)
    CustomerMailer.ownership_invitation_email(ownership).deliver
  end
end
