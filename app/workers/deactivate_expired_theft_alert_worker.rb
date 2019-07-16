class DeactivateExpiredTheftAlertWorker < ScheduledWorker
  def self.frequency
    24.hours
  end

  def perform
    record_scheduler_started

    TheftAlert
      .should_expire
      .update_all(status: TheftAlert.statuses[:inactive])

    record_scheduler_finished
  end
end
