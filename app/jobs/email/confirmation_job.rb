# frozen_string_literal: true

class Email::ConfirmationJob < ApplicationJob
  sidekiq_options queue: "notify", retry: 3

  PROCESS_NEW_EMAIL_DOMAINS = !Rails.env.test?

  def perform(user_id)
    user = User.find(user_id)

    # Don't suffer a witch to live
    if PROCESS_NEW_EMAIL_DOMAINS
      email_domain = EmailDomain.find_or_create_for(user.email, skip_processing: true)
      # Async processing for existing domains, inline for new ones
      email_domain.unprocessed? ? email_domain.process! : email_domain.enqueue_processing_worker

      return user.really_destroy! if email_domain.banned?
    end

    # Clean up situations where there are two users created
    return user.really_destroy! if duplicate_user?(user)

    # Create a likely_spam_reason and don't send a notification if ban_pending
    return UserLikelySpamReason.create(reason: "email_domain", user:) if email_domain&.ban_pending?

    notifications = user.notifications.confirmation_email.where("created_at > ?", Time.current - 1.minute)
    # If we just sent it, don't send again
    return false if notifications.delivery_success.any?
    notification = notifications.last || Notification.create(user_id: user.id, kind: "confirmation_email")

    notification.track_email_delivery do
      CustomerMailer.confirmation_email(user).deliver_now
    end
  end

  def duplicate_user?(user)
    User.where(email: user.email).where("id < ?", user.id).present?
  end
end
