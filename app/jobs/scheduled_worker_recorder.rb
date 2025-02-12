module ScheduledWorkerRecorder
  def perform(*args)
    return super if args.present?

    record_scheduler_started
    super
    record_scheduler_finished
  end
end
