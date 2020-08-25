class EmailOwnershipInvitationWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(ownership_id)
    ownership = Ownership.find_by_id(ownership_id)
    return true unless ownership.present? && ownership.bike.present?
    ownership.bike&.update_attributes(updated_at: Time.current)
    ownership.reload
    if ownership.calculated_send_email
      OrganizedMailer.finished_registration(ownership).deliver_now
    elsif ownership.send_email # Update the ownership to have send email set
      ownership.update_attribute :send_email, ownership.calculated_send_email
    end
  end
end
