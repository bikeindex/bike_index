class EmailResetPasswordWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(user_id)
    user = User.find(user_id)
    unless user.token_for_password_reset.present?
      raise StandardError, "User #{user_id} does not have a token_for_password_reset"
    end
    CustomerMailer.password_reset_email(user).deliver_now
  end
end
