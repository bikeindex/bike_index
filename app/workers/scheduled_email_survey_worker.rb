class EmailWelcomeWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(user_id)
    user = User.find(user_id)
    CustomerMailer.welcome_email(user).deliver_now
  end
end
