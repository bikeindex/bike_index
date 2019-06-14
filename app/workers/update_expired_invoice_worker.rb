class UpdateExpiredInvoiceWorker < ScheduledWorker
  def self.frequency
    12.hours
  end

  def perform
    record_scheduler_started
    Invoice.should_expire.each { |invoice| invoice.update_attributes(updated_at: Time.current) }
    record_scheduler_finished
  end
end
