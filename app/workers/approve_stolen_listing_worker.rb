class ApproveStolenListingWorker < ApplicationWorker
  sidekiq_options queue: "notify"

  def perform(bike_id)
    StolenTwitterbotIntegration.new.send_tweet(bike_id)
  end
end
