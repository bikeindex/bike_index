class ResetPasswordEmailJob
  @queue = 'email'

  def self.perform(user_id)
    user = User.find(user_id)
    CustomerMailer.password_reset_email(user).deliver
  end
end
