# frozen_string_literal: true

module Email
  class WelcomeJob < ApplicationJob
    sidekiq_options queue: "notify", retry: 3

    def perform(user_id)
      user = User.find(user_id)
      # Don't send an email if the email is blocked
      return if EmailBan.ban?(user)

      CustomerMailer.welcome_email(user).deliver_now
    end
  end
end
