# frozen_string_literal: true

class EmailConfirmationJob < ApplicationJob
  sidekiq_options queue: "notify", retry: 3

  def perform(user_id)
    user = User.find(user_id)

    # Don't suffer a witch to live
    email_domain = EmailDomain.find_or_create_for(user.email)
    return user.really_destroy! if email_domain.banned?

    # Clean up situations where there are two users created
    return user.destroy if duplicate_user?(user)
    return if email_domain.ban_pending?

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
