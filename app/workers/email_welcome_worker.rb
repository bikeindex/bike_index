class EmailWelcomeWorker < ApplicationWorker
  sidekiq_options queue: "notify"

  def perform(user_id)
    user = User.find(user_id)
    CustomerMailer.welcome_email(user).deliver_now
  end
end
