module ScheduledWorkerRecorder
  def perform(*args, **kwargs)
    if [*args, *kwargs.values].all?(&:blank?)
      record_scheduler_started
      super()
      record_scheduler_finished
    else
      super(*args, **kwargs)
    end
  end
end
