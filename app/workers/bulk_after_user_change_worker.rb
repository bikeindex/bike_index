class BulkAfterUserChangeWorker < AfterUserChangeWorker
  sidekiq_options retry: false, queue: "low_priority"

  def self.migration_at
    Time.at((ENV["MIGRATION_START"] || 1641517243).to_i)
  end

  def self.enqueue?
    # Skip if the queue is backing up
    !ScheduledWorker.enqueued?
  end

  def self.bikes
    Bike.reorder(updated_at: :desc).where("bikes.updated_at < ?", migration_at)
  end

  def self.users
    User.reorder(updated_at: :desc).where("users.updated_at < ?", migration_at)
  end

  def self.ownerships
    Ownership.reorder(updated_at: :desc).where("ownerships.updated_at < ?", migration_at)
  end
end
