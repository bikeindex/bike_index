module ScheduledJobRecorder
  def perform(*args, **kwargs)
    return super if args.present? || kwargs.present?

    record_scheduler_started
    super
    record_scheduler_finished
  end
end
