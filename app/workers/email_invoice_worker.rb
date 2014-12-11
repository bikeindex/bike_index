class EmailInvoiceWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'email'
  sidekiq_options backtrace: true

  def perform(id)
    @payment = Payment.find(id)
    CustomerMailer.invoice_email(@payment).deliver
  end

end