class DeactivateExpiredTheftAlertWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    24.hours
  end

  def perform
    TheftAlert
      .should_expire
      .update_all(status: TheftAlert.statuses[:inactive])
  end
end
