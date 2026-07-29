class CleanBParamsJob < ScheduledJob
  prepend ScheduledJobRecorder

  def self.frequency
    25.hours
  end

  def self.clean_before
    Time.current - 24.hours
  end

  def perform
    b_params.delete_all
  end

  # Registrations that made their bike, plus never-submitted blank shells
  def b_params
    stale = BParam.where("updated_at < ?", self.class.clean_before)
    stale.with_bike.or(stale.without_bike_values)
  end
end
