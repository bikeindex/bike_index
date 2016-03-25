class EmailOwnershipInvitationWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'notify'
  sidekiq_options backtrace: true

  def perform(ownership_id)
    ownership = Ownership.find(ownership_id)
    ownership.bike.save
    ownership.reload
    CustomerMailer.ownership_invitation_email(ownership).deliver
  end
end
