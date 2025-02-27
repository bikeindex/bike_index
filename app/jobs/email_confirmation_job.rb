# frozen_string_literal: true

class EmailConfirmationJob < ApplicationJob
  sidekiq_options queue: "notify", retry: 3

  def self.banned_email_domain?(email)
    BannedEmailDomain.pluck(:domain).any? { |domain| email.end_with?(domain) }
  end

  def perform(user_id)
    user = User.find(user_id)

    # Don't suffer a witch to live
    return user.really_destroy! if self.class.banned_email_domain?(user.email)

    # Clean up situations where there are two users created
    return user.destroy if duplicate_user?(user)

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
