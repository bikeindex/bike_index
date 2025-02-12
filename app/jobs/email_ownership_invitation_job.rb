class EmailOwnershipInvitationJob < ApplicationJob
  sidekiq_options queue: "notify", retry: 3

  def perform(ownership_id)
    ownership = Ownership.find_by_id(ownership_id)
    return true unless ownership.present? && ownership.bike.present?
    # recalculate spaminess, to verify that bike should be emailed
    if SpamEstimator.estimate_bike(ownership.bike) > SpamEstimator::MARK_SPAM_PERCENT
      ownership.bike.update(likely_spam: true) unless ownership.bike.likely_spam?
    end
    ownership.bike&.update(updated_at: Time.current)
    ownership.reload

    if ownership.calculated_send_email != ownership.send_email
      # Update the ownership to have send email set
      ownership.update_attribute(:skip_email, !ownership.calculated_send_email)
    end
    return if ownership.skip_email

    notification = Notification.find_or_create_by(notifiable: ownership,
      kind: "finished_registration")

    notification.track_email_delivery do
      OrganizedMailer.finished_registration(ownership).deliver_now
    end
  end
end
