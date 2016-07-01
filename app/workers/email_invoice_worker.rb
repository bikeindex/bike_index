class EmailInvoiceWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'notify'
  sidekiq_options backtrace: true

  def perform(id)
    @payment = Payment.find(id)
    CustomerMailer.invoice_email(@payment).deliver_now
  end

end