class EmailBikeTokenInvitationWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'email'
  sidekiq_options backtrace: true

  def perform(btinvitation_id)
    btinvitation = BikeTokenInvitation.find(btinvitation_id)
    CustomerMailer.bike_token_invitation_email(btinvitation).deliver
  end
end
