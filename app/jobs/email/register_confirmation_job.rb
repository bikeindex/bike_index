# frozen_string_literal: true

module Email
  class RegisterConfirmationJob < ApplicationJob
    include BParamNotification

    sidekiq_options queue: "notify", retry: 3

    def perform(b_param_id)
      b_param = BParam.find_by(id: b_param_id)
      return if b_param.blank? || b_param.email_confirmed? ||
        b_param.email_confirmation_token.blank?

      deliver_b_param_notification(b_param, kind: "register_confirmation") do
        OrganizedMailer.register_confirmation(b_param).deliver_now
      end
    end
  end
end
