# frozen_string_literal: true

class Email::ConfirmationJob < ApplicationJob
  sidekiq_options queue: "notify", retry: 3

  def perform(user_id)
    user = User.find_by(id: user_id)
    return if user.blank?

    # Don't send an email if the email is blocked
    return if EmailBan.ban?(user)
    # Clean up situations where there are two users created
    return user.really_destroy! if duplicate_user?(user)

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
end
