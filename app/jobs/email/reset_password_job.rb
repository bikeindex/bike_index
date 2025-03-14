# frozen_string_literal: true

class Email::ResetPasswordJob < ApplicationJob
  sidekiq_options queue: "notify", retry: 3

  NOTIFICATION_KIND = "password_reset"

  def perform(user_id)
    user = User.find(user_id)
    unless user.token_for_password_reset.present?
      raise StandardError, "User #{user_id} does not have a token_for_password_reset"
    end
    # We dnn't send email to banned users
    return if user.banned?

    notification_for_password_reset_token(user).track_email_delivery do
      CustomerMailer.password_reset_email(user).deliver_now
    end
  end

  private

  def notification_for_password_reset_token(user)
    token_time = user.auth_token_time("token_for_password_reset")
    Notification.where(user_id: user.id, kind: NOTIFICATION_KIND)
      .where("created_at > ?", token_time).first ||
      Notification.create(user_id: user.id, kind: NOTIFICATION_KIND)
  end
end
