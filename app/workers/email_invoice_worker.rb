class EmailInvoiceWorker < ApplicationWorker

  sidekiq_options queue: "notify"

  def perform(id)
    @payment = Payment.find(id)
    CustomerMailer.invoice_email(@payment).deliver_now
  end
end
