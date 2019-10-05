class UpdateExpiredInvoiceWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    12.hours
  end

  def perform
    Invoice.should_expire.each { |invoice| invoice.update_attributes(updated_at: Time.current) }
  end
end
