class BulkAfterUserChangeWorker < AfterUserChangeWorker
  sidekiq_options retry: false, queue: "low_priority"

  def self.migration_at
    Time.at(ENV["MIGRATION_START"] || 1641517243)
  end

  def self.bikes
    Bike.reorder(:updated_at).where("bikes.updated_at < ?", migration_at)
  end
end
