class EmailInvoiceWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(id)
    @payment = Payment.find(id)
    CustomerMailer.invoice_email(@payment).deliver_now
  end
end
