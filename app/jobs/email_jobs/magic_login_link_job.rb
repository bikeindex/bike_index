# frozen_string_literal: true

module EmailJobs
  class MagicLoginLinkJob < ApplicationJob
    sidekiq_options queue: "notify", retry: 3

    def perform(user_id, return_to = nil)
      user = User.find(user_id)
      unless user.magic_link_token.present?
        raise StandardError, "User #{user_id} does not have a magic_link_token"
      end

      notification = user.notifications.magic_login_link
        .where("created_at > ?", user.auth_token_time("magic_link_token")).first_or_create
      Notifications::Deliver.track_email(notification) do
        CustomerMailer.magic_login_link_email(user, return_to:).deliver_now
      end
    end
  end
end
