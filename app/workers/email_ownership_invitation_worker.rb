class EmailOwnershipInvitationWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(ownership_id)
    ownership = Ownership.find_by_id(ownership_id)
    return true unless ownership.present? && ownership.bike.present?
    ownership.bike&.update(updated_at: Time.current)
    ownership.reload

    if ownership.calculated_send_email != ownership.send_email
      # Update the ownership to have send email set
      ownership.update_attribute(:skip_email, !ownership.calculated_send_email)
    end
    return if ownership.skip_email

    notification = Notification.find_or_create_by(notifiable: ownership,
      kind: "finished_registration")
    unless notification.delivered?
      OrganizedMailer.finished_registration(ownership).deliver_now
      notification.update(delivery_status: "email_success") # This could be made more representative
    end
  end
end
