module ScheduledWorkerRecorder
  def perform
    record_scheduler_started
    super
    record_scheduler_finished
  end
end
