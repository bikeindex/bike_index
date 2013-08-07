class BikeTokenInvitationEmailJob
  @queue = "email"

  def self.perform(btinvitation_id)
    btinvitation = BikeTokenInvitation.find(btinvitation_id)
    CustomerMailer.bike_token_invitation_email(btinvitation).deliver
  end
end
