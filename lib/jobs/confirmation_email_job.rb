class ConfirmationEmailJob
  @queue = 'email'

  def self.perform(user_id)
    user = User.find(user_id)
    CustomerMailer.confirmation_email(user).deliver
  end
end
