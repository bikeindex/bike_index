class UpdateLoggedSearchCountsJob < ScheduledJob
  prepend ScheduledJobRecorder

  sidekiq_options queue: "droppable"

  def self.frequency
    65.minutes
  end

  def perform
    Counts.assign_logged_searches
  end
end
