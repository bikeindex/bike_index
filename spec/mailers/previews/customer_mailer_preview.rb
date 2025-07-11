# Preview emails at /rails/mailers/customer_mailer
class CustomerMailerPreview < ActionMailer::Preview
  def welcome_email
    CustomerMailer.welcome_email(preview_user)
  end

  def confirmation_email
    CustomerMailer.confirmation_email(preview_user)
  end

  def confirmation_email_partner
    CustomerMailer.confirmation_email(User.partner_sign_up.last)
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

  def user_alert_email
    user_alert = UserAlert.where(kind: UserAlert.notification_kinds).last

    CustomerMailer.user_alert_email(user_alert)
  end

  def theft_alert_posted
    theft_alert = TheftAlert.reorder(:created_at).last
    notification = theft_alert.notifications.where(kind: "theft_alert_posted").first
    notification ||= Notification.new(user: theft_alert.user,
      kind: "theft_alert_posted",
      message_channel: "email",
      notifiable: theft_alert)

    CustomerMailer.theft_alert_email(theft_alert, notification)
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
    stolen_notification = StolenNotification.stolen_permitted.last
    CustomerMailer.stolen_notification_email(stolen_notification)
  end

  def stolen_notification_unstolen_email
    stolen_notification = StolenNotification.unstolen_unclaimed_permitted.last
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

  def newsletter
    mail_snippet = MailSnippet.newsletter.order(:id).last
    user = User.confirmed.valid_only.reorder(:updated_at).last
    CustomerMailer.newsletter(user:, mail_snippet:)
  end

  def marketplace_message_notification
    CustomerMailer.marketplace_message_notification(MarketplaceMessage.last)
  end

  private

  def preview_user
    User.last
  end
end
