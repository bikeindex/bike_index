class WelcomeEmailJob
  @queue = 'email'

  def self.perform(user_id)
    user = User.find(user_id)
    CustomerMailer.welcome_email(user).deliver
  end
end
