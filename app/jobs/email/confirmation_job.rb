# frozen_string_literal: true

class Email::ConfirmationJob < ApplicationJob
  sidekiq_options queue: "notify", retry: 3

  BLOCK_DUPLICATE_PERIOD = 1.day
  PRE_PERIOD_DUPLICATE_LIMIT = 2

  def perform(user_id)
    user = User.find_by(id: user_id)
    return if user.blank?

    # Don't suffer a witch to live
    if EmailDomain::VERIFICATION_ENABLED
      email_domain = EmailDomain.find_or_create_for(user.email, skip_processing: true)
      # Async processing for existing domains, inline for new ones
      email_domain.unprocessed? ? email_domain.process! : email_domain.enqueue_processing_worker

      return user.really_destroy! if email_domain.banned?
    end

    # Clean up situations where there are two users created
    return user.really_destroy! if duplicate_user?(user)

    # Create a email ban if we should
    EmailBan.create(reason: :email_domain, user:) if email_domain&.provisional_ban?
    EmailBan.create(reason: :email_duplicate, user:) if email_duplicate?(user)
    # Don't send an email if the email is blocked
    return if EmailBan.period_started.where(user:).any?

    notifications = user.notifications.confirmation_email.where("created_at > ?", Time.current - 1.minute)
    # If we just sent it, don't send again
    return false if notifications.delivery_success.any?
    notification = notifications.last || Notification.create(user_id: user.id, kind: "confirmation_email")

    notification.track_email_delivery do
      CustomerMailer.confirmation_email(user).deliver_now
    end
  end

  private

  def duplicate_user?(user)
    User.where(email: user.email).where("id < ?", user.id).present?
  end

  def email_duplicate?(user)
    matches = User.where("REPLACE(email, '.', '') = ?", user.email.tr(".", ""))
      .where.not(email: user.email)

    return true if matches.where("created_at > ?", Time.current - BLOCK_DUPLICATE_PERIOD).any?

    matches.count > PRE_PERIOD_DUPLICATE_LIMIT
  end
end
