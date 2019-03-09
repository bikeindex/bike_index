class UpdateExpiredInvoiceWorker < ScheduledWorker
  def self.frequency
    12.hours
  end

  def perform
    Invoice.should_expire.each { |invoice| invoice.update_attributes(updated_at: Time.now) }
  end
end
