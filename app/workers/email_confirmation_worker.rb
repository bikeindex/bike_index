class EmailConfirmationWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(user_id)
    user = User.find(user_id)
    # We need to clean up situations where there are two users created
    return user.destroy if User.where(email: user.email).where("id < ?", user_id).present?
    notifications = user.notifications.confirmation_email.where("created_at > ?", Time.current - 1.minute)
    # If we just sent it, don't send again
    return false if notifications.email_success.any?
    notification = notifications.last || Notification.create(user_id: user.id, kind: "confirmation_email")
    CustomerMailer.confirmation_email(user).deliver_now
    notification.update(delivery_status: "email_success") # I'm not sure how to make this more representative
  end
end
