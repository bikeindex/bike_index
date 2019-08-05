class EmailOwnershipInvitationWorker < ApplicationWorker
  sidekiq_options queue: "notify"

  def perform(ownership_id)
    ownership = Ownership.where(id: ownership_id).first
    return true unless ownership.present?
    return true unless ownership.owner_email.present?
    ownership.bike.save
    ownership.reload
    OrganizedMailer.finished_registration(ownership).deliver_now
  end
end
