class UserPhoneConfirmationJob < ApplicationJob
  sidekiq_options queue: "notify", retry: 1
  UPDATE_TWILIO = ENV["UPDATE_TWILIO_ENABLED"] == "true"

  def perform(user_phone_id, skip_user_update = false)
    return unless Flipper.enabled?(:phone_verification)
    user_phone = UserPhone.find(user_phone_id)
    notification = Notification.create(user: user_phone.user,
      kind: "phone_verification",
      message_channel: "text",
      notifiable: user_phone)

    if UPDATE_TWILIO
      Integrations::Twilio.new.send_notification(notification,
        to: user_phone.phone,
        body: user_phone.confirmation_message)
    end

    return true if skip_user_update
    # Manually run after user change to add a user alert
    # (rather than spinning up a new worker)
    AfterUserChangeJob.new.perform(user_phone.user_id, user_phone.user)
  end
end
