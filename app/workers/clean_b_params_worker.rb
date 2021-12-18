class CleanBParamsWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    25.hours
  end

  def self.clean_before
    Time.current - 24.hours
  end

  def perform
    b_params.delete_all
  end

  def b_params
    BParam.with_bike.where("updated_at < ?", self.class.clean_before)
  end
end
