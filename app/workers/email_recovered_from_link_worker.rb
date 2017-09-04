class EmailRecoveredFromLinkWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'notify'
  sidekiq_options backtrace: true

  def perform(stolen_record_id)
    stolen_record = StolenRecord.unscoped.find(stolen_record_id)
    CustomerMailer.recovered_from_link(stolen_record).deliver_now
  end
end
