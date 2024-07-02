# NOTE: logged_searches are created by ScheduledStoreLogSearchesWorker
# This adds location data and updates the association

class ProcessLoggedSearchWorker < ApplicationWorker
  sidekiq_options queue: "droppable", retry: 1

  def perform(logged_search_id)
  end
end
