class EmailOwnershipInvitationWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'email'
  sidekiq_options backtrace: true

  def perform(ownership_id)
    ownership = Ownership.find(ownership_id)
    CustomerMailer.ownership_invitation_email(ownership).deliver
  end
end
