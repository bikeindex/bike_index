# frozen_string_literal: true

module Email
  # The emails a registration sends before it has a bike, and so before there's an
  # account to notify - the address itself is all that's been entered, so every one
  # of them runs the domain check first
  module BParamNotification
    def deliver_b_param_notification(b_param, kind:)
      if EmailDomain::VERIFICATION_ENABLED
        email_domain = EmailDomain.find_or_create_for(b_param.owner_email)

        return b_param.destroy if email_domain&.banned?
        return if email_domain&.provisional_ban?
      end

      notification = Notification.create(kind:, message_channel: "email", notifiable: b_param)
      notification.track_email_delivery { yield }
    end
  end
end
