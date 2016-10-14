# Preview emails at /rails/mailers/customer_mailer
class CustomerMailerPreview < ActionMailer::Preview
  def welcome_email
    CustomerMailer.welcome_email(preview_user)
  end

  def confirmation_email
    CustomerMailer.confirmation_email(preview_user)
  end

  def password_reset_email
    CustomerMailer.password_reset_email(preview_user)
  end

  def additional_email_confirmation
    user_email = UserEmail.unconfirmed.last
    CustomerMailer.additional_email_confirmation(user_email)
  end

  def invoice_email
    payment = Payment.last
    CustomerMailer.invoice_email(payment)
  end

  def stolen_bike_alert_email
    customer_contact = CustomerContact.last
    CustomerMailer.stolen_bike_alert_email(customer_contact)
  end

  def admin_contact_stolen_email
    customer_contact = CustomerContact.where(contact_type: 'stolen_contact').last
    CustomerMailer.admin_contact_stolen_email(customer_contact)
  end

  def stolen_notification_email
    stolen_notification = StolenNotification.last
    CustomerMailer.stolen_notification_email(stolen_notification)
  end

  private

  def preview_user
    User.last
  end
end
