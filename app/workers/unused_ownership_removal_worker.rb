class UnusedOwnershipRemovalWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    23.hours
  end

  def perform(id = nil)
    if id.blank?
      enqueue_scheduled_jobs
    else
      remove_unused_ownership(id)
    end
  end

  def remove_unused_ownership(ownership_id)
    ownership = Ownership.find(ownership_id)
    return if Bike.unscoped.exists?(id: ownership.bike_id)

    ownership.update_attribute :current, false
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
