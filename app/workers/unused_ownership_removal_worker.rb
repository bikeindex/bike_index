class UnusedOwnershipRemovalWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    23.hours
  end

  def perform(id = nil)
    return enqueue_scheduled_jobs if id.blank?
    ownership = Ownership.find(id)
    unless Bike.unscoped.where(id: ownership.bike_id).present?
      ownership.update_attribute :current, false
    end
  end

  def enqueue_scheduled_jobs
    # Rather than doing all the ownerships, just do a random slice
    Ownership.where(current: true)
             .order("RANDOM()")
             .limit(50_000)
             .pluck(:id)
             .each { |id| UnusedOwnershipRemovalWorker.perform_async(id) }
  end
end
