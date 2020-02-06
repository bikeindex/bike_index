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

  def magic_login_link_email
    user = User.where.not(magic_link_token: nil).reorder(:updated_at).last
    if user.blank?
      user = preview_user
      preview_user.update_auth_token("magic_link_token")
    end
    CustomerMailer.magic_login_link_email(user)
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
    customer_contact =
      CustomerContact
        .includes(:bike)
        .where(bike_id: Bike.select(:id))
        .where.not("info_hash->>'tweet_account_name' = ''")
        .last

    CustomerMailer.stolen_bike_alert_email(customer_contact)
  end

  def admin_contact_stolen_email
    customer_contact =
      CustomerContact
        .includes(:bike)
        .stolen_contact
        .where(bike_id: Bike.select(:id))
        .last

    CustomerMailer.admin_contact_stolen_email(customer_contact)
  end

  def stolen_notification_email
    stolen_notification = StolenNotification.last
    CustomerMailer.stolen_notification_email(stolen_notification)
  end

  def updated_terms_email
    CustomerMailer.updated_terms_email(User.find(85))
  end

  def recovered_from_link
    recovered_record = StolenRecord.recovered_ordered.where.not(recovered_at: nil).first
    CustomerMailer.recovered_from_link(recovered_record)
  end

  def bike_possibly_found_email
    contact = CustomerContact.bike_possibly_found.last
    CustomerMailer.bike_possibly_found_email(contact)
  end

  private

  def preview_user
    User.last
  end
end
