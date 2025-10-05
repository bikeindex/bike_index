# frozen_string_literal: true

class Email::NewsletterJob < ApplicationJob
  sidekiq_options queue: "low_priority", retry: 1

  class << self
    def enqueue_for(mail_snippet_id, limit: 1_000)
      users_to_send(mail_snippet_id).limit(limit).pluck(:id)
        .each { |id| Email::NewsletterJob.perform_async(id, mail_snippet_id) }
    end

    def users_to_send(mail_snippet_id)
      User.confirmed.valid_only.where(notification_newsletters: true)
        .where.not(id: Notification.delivery_success.newsletter.where(notifiable_id: mail_snippet_id).select(:user_id))
    end
  end

  def perform(user_id, mail_snippet_id, force_send = false)
    user = User.find_by(id: user_id)
    mail_snippet = MailSnippet.newsletter.find(mail_snippet_id)
    return if user.blank? || mail_snippet.blank?

    unless force_send
      # Don't send an email if the email is blocked
      return if EmailBan.ban?(user) || !user.notification_newsletters

      notifications = user.notifications.newsletter.where(notifiable_id: mail_snippet_id)

      # If we sent already, don't send again
      return false if notifications.delivery_success.any?

      notification = notifications.last
    end

    notification ||= Notification.create(user_id: user.id, kind: :newsletter, notifiable: mail_snippet)

    notification.track_email_delivery do
      CustomerMailer.newsletter(user:, mail_snippet:).deliver_now
    end
  end
end
