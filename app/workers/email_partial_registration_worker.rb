class EmailPartialRegistrationWorker < ApplicationWorker

  sidekiq_options queue: "notify"

  def perform(b_param_id)
    b_param = BParam.find(b_param_id)
    OrganizedMailer.partial_registration(b_param).deliver_now
  end
end
