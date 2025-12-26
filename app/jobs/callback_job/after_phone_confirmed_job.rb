class CallbackJob::AfterPhoneConfirmedJob < ApplicationJob
  sidekiq_options queue: "high_priority"

  def perform(user_phone_id)
    user_phone = UserPhone.find(user_phone_id)
    return true unless user_phone.confirmed?

    # Add the bikes to the user
    Bike.where(is_phone: true, owner_email: user_phone.phone).each do |bike|
      bike.current_ownership.create_user_registration_for_phone_registration!(user_phone.user)
    end

    # Manually run after user change to update user alerts
    ::CallbackJob::AfterUserChangeJob.new.perform(user_phone.user_id, user_phone.user)
  end
end
