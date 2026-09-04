# frozen_string_literal: true

module Email
  class WelcomeJob < ApplicationJob
    sidekiq_options queue: "notify", retry: 3

    def perform(user_id)
      user = User.find(user_id)
      notification = user.notifications.welcome_email.last ||
        Notification.create(user_id: user.id, kind: :welcome_email)

      Notification.track_email_delivery(notification, destroy_for_banned_domain: true) do
        CustomerMailer.welcome_email(user).deliver_now
      end
    end
  end
end
