class EmailPartialRegistrationWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(b_param_id)
    b_param = BParam.find(b_param_id)
    OrganizedMailer.partial_registration(b_param).deliver_now
  end
end
