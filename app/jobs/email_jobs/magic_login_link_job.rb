# frozen_string_literal: true

module EmailJobs
  class MagicLoginLinkJob < ApplicationJob
    sidekiq_options queue: "notify", retry: 3

    NOTIFICATION_KIND = "magic_login_link"

    def perform(user_id, return_to = nil)
      user = User.find(user_id)
      unless user.magic_link_token.present?
        raise StandardError, "User #{user_id} does not have a magic_link_token"
      end

      Notifications::Deliver.track_email(notification_for_magic_link_token(user)) do
        CustomerMailer.magic_login_link_email(user, return_to:).deliver_now
      end
    end

    private

    def notification_for_magic_link_token(user)
      token_time = user.auth_token_time("magic_link_token")
      Notification.where(user_id: user.id, kind: NOTIFICATION_KIND)
        .where("created_at > ?", token_time).first ||
        Notification.create(user_id: user.id, kind: NOTIFICATION_KIND)
    end
  end
end
