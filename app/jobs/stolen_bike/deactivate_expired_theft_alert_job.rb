class StolenBike::DeactivateExpiredPromotedAlertJob < ScheduledJob
  prepend ScheduledJobRecorder

  def self.frequency
    23.5.hours
  end

  def perform
    PromotedAlert
      .should_expire
      .update_all(status: "inactive")
  end
end
