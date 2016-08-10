class EmailAdminContactStolenWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'notify'
  sidekiq_options backtrace: true

  def perform(customer_contact_id)
    customer_contact = CustomerContact.find(customer_contact_id)
    CustomerMailer.admin_contact_stolen_email(customer_contact).deliver_now
  end
end
