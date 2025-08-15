class UpdateInvoiceJob < ScheduledJob
  prepend ScheduledJobRecorder

  def self.frequency
    12.hours
  end

  def perform
    Invoice.should_activate.or(Invoice.should_expire)
      .each { |invoice| invoice.update(updated_at: Time.current) }
  end
end
