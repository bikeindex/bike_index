class EmailConfirmationWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(user_id)
    user = User.find(user_id)
    # We need to clean up situations where there are two users created
    return user.destroy if User.where(email: user.email).where("id < ?", user_id).present?
    CustomerMailer.confirmation_email(user).deliver_now
  end
end
