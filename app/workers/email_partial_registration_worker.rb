class EmailPartialRegistrationWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  # When we started creating notifications when sending partial registration emails PR#2368
  NOTIFICATION_STARTED = Time.at(1690677345).freeze # 2023-07-29 17:35:45

  def perform(b_param_id)
    b_param = BParam.find(b_param_id)
    if b_param.present?
      notification = Notification.create(kind: "partial_registration",
        message_channel: "email",
        notifiable: b_param)

      OrganizedMailer.partial_registration(b_param).deliver_now
      notification.update(delivery_status: "email_success")
    end
  end
end
