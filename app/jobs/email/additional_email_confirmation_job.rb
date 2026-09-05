module Email
  class AdditionalEmailConfirmationJob < ApplicationJob
    sidekiq_options queue: "notify", retry: 3

    def perform(user_email_id)
      user_email = UserEmail.find_by(id: user_email_id)
      return if user_email.blank?

      notifications = user_email.notifications.additional_email_confirmation
        .where("created_at > ?", Time.current - 1.minute)
      return if notifications.delivery_success.any?

      notification = notifications.last ||
        Notification.create(kind: "additional_email_confirmation", notifiable: user_email)

      notification.track_email_delivery(is_new_email_address: true) do
        CustomerMailer.additional_email_confirmation(user_email).deliver_now
      end
    end
  end
end
