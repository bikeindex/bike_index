class DeactivateExpiredTheftAlertWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    23.5.hours
  end

  def perform
    TheftAlert
      .should_expire
      .update_all(status: "inactive")
  end
end
