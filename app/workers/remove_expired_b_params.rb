class RemoveExpiredBParamsWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'afterwards', backtrace: true, retry: false

  def perform(id)
    bikeParam = BParam.where(id: id).first
    if bikeParam.present? && bikeParam.created_at < Time.zone.now - 1.month
      bikeParam.destroy
    else
      true
    end
  end
end
