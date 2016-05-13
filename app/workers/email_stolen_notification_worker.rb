class EmailStolenNotificationWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'notify'
  sidekiq_options backtrace: true

  def perform(stolenNotification_id)
    @stolenNotification = StolenNotification.find(stolenNotification_id)
    CustomerMailer.stolenNotification_email(@stolenNotification).deliver
  end

end