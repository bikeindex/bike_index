class UserPhoneConfirmationWorker < ApplicationWorker
  sidekiq_options queue: "notify"

  def perform(user_phone_id, skip_user_update = false)
    user_phone = UserPhone.find(user_phone_id)
    notification = Notification.create(user: user_phone.user,
                                       kind: "phone_verification",
                                       message_channel: "text",
                                       notifiable: user_phone)

    TwilioIntegration.new.send_notification(notification,
      to: user_phone.phone,
      body: user_phone.confirmation_message)

    return true if skip_user_update
    # Manually run after user change to add a general alert to the user
    # (rather than spinning up a new worker)
    AfterUserChangeWorker.new.perform(user_phone.user_id, user_phone.user)
  end
end
