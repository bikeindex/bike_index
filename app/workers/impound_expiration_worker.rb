class ImpoundExpirationWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    24.5.hours
  end

  def perform
    ImpoundConfiguration.where.not(expiration_period_days: nil).each do |impound_configuration|
      impound_configuration.impound_records_to_expire.each { |i| i.impound_record_updates.create(kind: "expired") }
    end
  end
end
