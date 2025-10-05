class Email::AdditionalEmailConfirmationJob < ApplicationJob
  sidekiq_options queue: "notify"

  def perform(user_email_id)
    user_email = UserEmail.find_by(id: user_email_id)
    return if user_email.blank?

    CustomerMailer.additional_email_confirmation(user_email).deliver_now
  end
end
