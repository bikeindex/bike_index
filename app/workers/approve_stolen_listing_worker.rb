class ApproveStolenListingWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'notify'
  sidekiq_options backtrace: true
    
  def perform(bike_id)
    StolenTwitterbotIntegration.new.send_tweet(bike_id)
  end

end