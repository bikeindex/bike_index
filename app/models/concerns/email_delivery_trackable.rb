# frozen_string_literal: true

# For records that own an email's delivery_status. An includer lists who it emails in
# recipient_users and recipient_emails
module EmailDeliveryTrackable
  extend ActiveSupport::Concern

  included do
    scope :delivered, -> { where(delivery_status: Notification::DELIVERED_STATUSES) }
    # A send we blocked is as undelivered as one postmark refused
    scope :delivery_failed, -> { where(delivery_status: %w[delivery_failure delivery_banned]) }
  end

  # Raises the delivery's error, unless the addresses are undeliverable
  def track_email_delivery(is_new_email_address: false)
    return if delivery_settled?

    return update(delivery_status: "delivery_banned") if email_banned?(is_new_email_address)

    # Only the send is rescued - a ban evaluation that blows up hasn't failed to deliver anything
    begin
      handle_email_delivery_success(yield)
    rescue => e
      handle_email_delivery_error(e)
    end
  end

  # A settled delivery isn't worth sending again - it delivered, or its addresses are dead
  def delivery_settled?
    Notification::DELIVERED_STATUSES.include?(delivery_status) ||
      Notification::UNDELIVERABLE_ERROR_NAMES.include?(delivery_error)
  end

  private

  def email_ban_exempt?
    false
  end

  # A ban covers one address, so only a batch that's entirely banned is blocked
  def email_banned?(is_new_email_address)
    return false if email_ban_exempt? || recipients.none?

    recipients.all? { EmailBan.ban?(it, user_email: user_email_for(it), is_new_email_address:) }
  end

  def handle_email_delivery_success(delivery)
    update(delivery_status: "delivery_success", message_id: message_id || delivery.try(:message_id))
    recipient_user_emails.each { it.update_last_email_errored!(email_errored: false) }
    nil
  end

  # Postmark delivers to the rest of a batch, whether or not it names who it rejected - and an
  # error it doesn't attribute can only be pinned on a lone recipient
  def handle_email_delivery_error(error)
    inactive_recipient_error = error.is_a?(Postmark::InactiveRecipientError)
    named_emails = inactive_recipient_error ? normalized(error.recipients) : []
    failed_emails = named_emails.presence || (recipient_addresses.one? ? recipient_addresses : [])
    delivered_any = inactive_recipient_error && (recipient_addresses - failed_emails).any?
    update(delivery_status: delivered_any ? "delivery_partial_success" : "delivery_failure",
      delivery_error: error.class)
    # Postmark refuses a deactivated address itself, so this doesn't block anything -
    # it's recorded to show why the emails stopped arriving
    recipient_user_emails.select { failed_emails.include?(it.email) }
      .each { it.update_last_email_errored!(email_errored: true) }

    raise error unless Notification::UNDELIVERABLE_ERROR_NAMES.include?(error.class.name)
  end

  def recipients
    @recipients ||= recipient_users.to_a
  end

  def recipient_addresses
    @recipient_addresses ||= normalized(recipient_emails)
  end

  # Addresses are held per user, so an address shared with another account is theirs alone
  def recipient_user_emails
    @recipient_user_emails ||= UserEmail.where(user_id: recipients.map(&:id), email: recipient_addresses).to_a
  end

  def user_email_for(user)
    recipient_user_emails.find { it.user_id == user.id }
  end

  def normalized(emails)
    emails.map { EmailNormalizer.normalize(it) }
  end
end
