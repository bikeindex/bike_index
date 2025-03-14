# frozen_string_literal: true

class Email::PartialRegistrationJob < ApplicationJob
  sidekiq_options queue: "notify", retry: 3

  # When we started creating notifications when sending partial registration emails PR#2368
  NOTIFICATION_STARTED = Time.at(1690677345).freeze # 2023-07-29 17:35:45

  def perform(b_param_id)
    b_param = BParam.find(b_param_id)
    return if b_param.blank?

    if EmailDomain::VERIFICATION_ENABLED
      email_domain = EmailDomain.find_or_create_for(b_param.owner_email)

      return b_param.destroy if email_domain&.banned?
      return if email_domain&.ban_pending?
    end

    notification = Notification.create(kind: "partial_registration",
      message_channel: "email",
      notifiable: b_param)

    notification.track_email_delivery do
      OrganizedMailer.partial_registration(b_param).deliver_now
    end
  end
end
