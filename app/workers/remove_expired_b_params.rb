class RemoveExpiredBParamsWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'afterwards', backtrace: true, retry: false

  def perform(id)
    b_param = BParam.where(id: id).first
    if b_param.present? && b_param.created_at < Time.zone.now - 1.month
      b_param.destroy
    else
      true
    end
  end
end
