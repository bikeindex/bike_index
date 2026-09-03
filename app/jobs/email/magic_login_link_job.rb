# frozen_string_literal: true

module Email
  class MagicLoginLinkJob < ApplicationJob
    sidekiq_options queue: "notify", retry: 3

    def perform(user_id, return_to = nil)
      user = User.find(user_id)
      unless user.magic_link_token.present?
        raise StandardError, "User #{user_id} does not have a magic_link_token"
      end

      CustomerMailer.magic_login_link_email(user, return_to:).deliver_now
      user_email_for(user)&.update_last_email_errored!(email_errored: false)
    rescue => e
      raise e if user.nil?

      user_email_for(user)&.update_last_email_errored!(email_errored: true)
      raise e unless EmailDeliveryTrackable::UNDELIVERABLE_ERRORS.any? { |error_class| e.is_a?(error_class) }
    end

    private

    def user_email_for(user)
      user.user_emails.friendly_find(user.email)
    end
  end
end
