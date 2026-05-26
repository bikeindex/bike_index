# frozen_string_literal: true

module Email
  class MagicLoginLinkJob < ApplicationJob
    sidekiq_options queue: "notify", retry: 3

    def perform(user_id)
      user = User.find(user_id)
      unless user.magic_link_token.present?
        raise StandardError, "User #{user_id} does not have a magic_link_token"
      end

      CustomerMailer.magic_login_link_email(user).deliver_now
      user_email_for(user)&.update_last_email_errored!(email_errored: false)
    rescue => e
      raise e if user.nil?

      user_email_for(user)&.update_last_email_errored!(email_errored: true)
      raise e unless Notification::UNDELIVERABLE_ERRORS.include?(e.class.to_s)
    end

    private

    def user_email_for(user)
      user.user_emails.friendly_find(user.email)
    end
  end
end
