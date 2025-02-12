class UpdateCountsJob < ScheduledJob
  prepend ScheduledJobRecorder

  def self.frequency
    1.hours
  end

  def perform
    Counts.count_keys.each { |k| Counts.send(:"assign_#{k}") }
  end
end
