class EmailConfirmationWorker < ApplicationWorker

  sidekiq_options queue: "notify"

  def perform(user_id)
    user = User.find(user_id)
    CustomerMailer.confirmation_email(user).deliver_now
  end
end
