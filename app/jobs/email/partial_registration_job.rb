# frozen_string_literal: true

module Email
  class PartialRegistrationJob < ApplicationJob
    include BParamNotification

    sidekiq_options queue: "notify", retry: 3

    # When we started creating notifications when sending partial registration emails PR#2368
    NOTIFICATION_STARTED = Time.at(1690677345).freeze # 2023-07-29 17:35:45

    def perform(b_param_id)
      b_param = BParam.find(b_param_id)
      return if b_param.blank?

      deliver_b_param_notification(b_param, kind: "partial_registration") do
        OrganizedMailer.partial_registration(b_param).deliver_now
      end
    end
  end
end
