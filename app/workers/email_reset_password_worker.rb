class EmailResetPasswordWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(user_id)
    user = User.find(user_id)
    unless user.password_reset_token.present?
      raise StandardError, "User #{user_id} does not have a password_reset_token"
    end
    CustomerMailer.password_reset_email(user).deliver_now
  end
end
