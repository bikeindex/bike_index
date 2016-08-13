class EmailPartialRegistrationWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'notify'
  sidekiq_options backtrace: true

  def perform(b_param_id)
    b_param = BParam.find(b_param_id)
    OrganizedMailer.partial_registration(b_param).deliver_now
  end
end
