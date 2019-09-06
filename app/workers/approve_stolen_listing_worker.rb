class ApproveStolenListingWorker < ApplicationWorker
  sidekiq_options queue: "notify"

  def perform(bike_id)
  end
end
