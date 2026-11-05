# frozen_string_literal: true

module EmailJobs
  class ResetPasswordJob < ApplicationJob
    sidekiq_options queue: "notify", retry: 3

    def perform(user_id, return_to = nil)
      user = User.find(user_id)
      unless user.token_for_password_reset.present?
        raise StandardError, "User #{user_id} does not have a token_for_password_reset"
      end
      # We dnn't send email to banned users
      return if user.banned?

      notification = user.notifications.password_reset
        .where("created_at > ?", user.auth_token_time("token_for_password_reset")).first_or_create
      Notifications::Deliver.track_email(notification) do
        CustomerMailer.password_reset_email(user, return_to:).deliver_now
      end
    end
  end
end
