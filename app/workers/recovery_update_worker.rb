class RecoveryUpdateWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'updates'
  sidekiq_options backtrace: true
    
  def perform(stolen_record_id, info)
    stolen_record = StolenRecord.find(stolen_record_id)
    stolen_record.add_recovery_information(ActiveSupport::HashWithIndifferentAccess.new(info))
    stolen_record.save
  end

end