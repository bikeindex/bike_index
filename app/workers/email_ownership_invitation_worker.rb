class EmailOwnershipInvitationWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'notify'
  sidekiq_options backtrace: true

  def perform(ownership_id)
    ownership = Ownership.where(id: ownership_id).first
    return true unless ownership.present?
    ownership.bike.save
    ownership.reload
    OrganizedMailer.finished_registration(ownership).deliver_now
  end
end
