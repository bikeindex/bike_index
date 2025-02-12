# frozen_string_literal: true

class EmailResetPasswordWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  NOTIFICATION_KIND = "password_reset".freeze

  def perform(user_id)
    user = User.find(user_id)
    unless user.token_for_password_reset.present?
      raise StandardError, "User #{user_id} does not have a token_for_password_reset"
    end

    notification_for_password_reset_token(user).track_email_delivery do
      CustomerMailer.password_reset_email(user).deliver_now
    end
  end

  private

  def notification_for_password_reset_token(user)
    token_time = user.auth_token_time("token_for_password_reset")
    Notification.where(user_id: user.id, kind: NOTIFICATION_KIND)
      .where("created_at > ?", token_time).first ||
      Notification.new(user_id: user.id, kind: NOTIFICATION_KIND)
  end
end
