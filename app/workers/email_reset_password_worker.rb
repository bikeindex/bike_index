class EmailResetPasswordWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(user_id)
    user = User.find(user_id)
    unless user.password_reset_token.present?
      user.update_auth_token("password_reset_token")
      user.reload
    end
    CustomerMailer.password_reset_email(user).deliver_now
  end
end
