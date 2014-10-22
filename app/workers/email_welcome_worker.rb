class EmailWelcomeWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'email'
  sidekiq_options backtrace: true

  def perform(user_id)
    user = User.find(user_id)
    CustomerMailer.welcome_email(user).deliver
  end
end
