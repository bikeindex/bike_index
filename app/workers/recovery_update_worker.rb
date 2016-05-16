class RecoveryUpdateWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'updates'
  sidekiq_options backtrace: true
    
  def perform(stolenRecord_id, info)
    stolenRecord = StolenRecord.unscoped.find(stolenRecord_id)
    stolenRecord.add_recovery_information(ActiveSupport::HashWithIndifferentAccess.new(info))
    stolenRecord.save
  end

end