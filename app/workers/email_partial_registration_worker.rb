class EmailPartialRegistrationWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

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
