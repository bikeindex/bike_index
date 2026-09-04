# frozen_string_literal: true

module Email
  # The emails a registration sends before it has a bike - only an address has been
  # entered, so every one runs the domain check first. kind names both the notification
  # and the mailer method, and defaults for jobs enqueued before it took one
  class PartialRegistrationJob < ApplicationJob
    sidekiq_options queue: "notify", retry: 3

    # When we started creating notifications when sending partial registration emails PR#2368
    NOTIFICATION_STARTED = Time.at(1690677345).freeze # 2023-07-29 17:35:45

    def perform(b_param_id, kind = "partial_registration")
      raise ArgumentError, "Not a b_param kind: #{kind.inspect} (expected one of #{Notification.b_param_kinds.join(", ")})" unless kind.in?(Notification.b_param_kinds)

      b_param = BParam.find_by(id: b_param_id)
      return if b_param.blank?
      # confirm_email! spends the token, so a blank one means there's no link left to send
      return if kind == "partial_register_confirmation" && b_param.email_confirmation_token.blank?

      if EmailDomain::VERIFICATION_ENABLED
        email_domain = EmailDomain.find_or_create_for(b_param.owner_email)

        return b_param.destroy if email_domain&.banned?
        return if email_domain&.provisional_ban?
      end

      notification = Notification.create(kind:, message_channel: "email", notifiable: b_param)
      Notification.track_email_delivery(notification) { OrganizedMailer.public_send(kind, b_param).deliver_now }
    end
  end
end
