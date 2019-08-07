class EmailOwnershipInvitationWorker < ApplicationWorker

  sidekiq_options queue: "notify"

  def perform(ownership_id)
    ownership = Ownership.where(id: ownership_id).first
    return true unless ownership.present?
    ownership.bike.update_attributes(updated_at: Time.current)
    ownership.reload
    if ownership.calculated_send_email
      OrganizedMailer.finished_registration(ownership).deliver_now
    else
      # Update the ownership to have send email set
      if ownership.send_email
        ownership.update_attribute :send_email, ownership.calculated_send_email
      end
    end
  end
end
