module ScheduledJobRecorder
  def perform(*args, **kwargs)
    return super if args.present? || kwargs.present?
    return if skip_scheduling?

    record_scheduler_started
    super
    record_scheduler_finished
  end
end
