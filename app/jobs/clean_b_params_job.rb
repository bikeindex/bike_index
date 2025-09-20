class CleanBParamsJob < ScheduledJob
  prepend ScheduledJobRecorder

  def self.frequency
    25.hours
  end

  def self.clean_before
    24.hours.ago
  end

  def perform
    b_params.delete_all
  end

  def b_params
    BParam.with_bike.where("updated_at < ?", self.class.clean_before)
  end
end
