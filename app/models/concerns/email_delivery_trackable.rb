# frozen_string_literal: true

# For records that own an email's delivery_status. The record lists who it emails in
# recipient_users and recipient_emails; wrap the delivery in track_email_delivery
module EmailDeliveryTrackable
  extend ActiveSupport::Concern

  included do
    scope :delivered, -> { where(delivery_status: Notification::DELIVERED_STATUSES) }
    # Resending to addresses that rejected it just fails the same way
    scope :undeliverable, -> { where(delivery_error: Notification::UNDELIVERABLE_ERRORS.map(&:name)) }
    scope :delivery_settled, -> { delivered.or(undeliverable) }
    # A send we blocked is as undelivered as one postmark refused
    scope :delivery_failed, -> { where(delivery_status: %w[delivery_failure delivery_banned]) }
  end

  # Takes a block, which delivers the email. Raises its error, unless the addresses are undeliverable
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
    Notification::DELIVERED_STATUSES.include?(delivery_status) || undeliverable_error?(delivery_error)
  end

  private

  def email_ban_exempt?
    false
  end

  # A ban covers one address, so only a batch that's entirely banned is blocked
  def email_banned?(is_new_email_address)
    return false if email_ban_exempt?

    users = recipient_users.to_a
    user_emails = user_emails_for(normalized_recipient_emails)
    users.any? && users.all? do |user|
      EmailBan.ban?(user, user_email: user_emails.find { it.user_id == user.id }, is_new_email_address:)
    end
  end

  def handle_email_delivery_success(delivery)
    update(delivery_status: "delivery_success", message_id: message_id || delivery.try(:message_id))
    user_emails_for(normalized_recipient_emails).each { it.update_last_email_errored!(email_errored: false) }
    nil
  end

  # Postmark delivers to the rest of a batch, whether or not it names who it rejected - and an
  # error it doesn't attribute can only be pinned on a lone recipient
  def handle_email_delivery_error(error)
    emails = normalized_recipient_emails
    inactive_recipient_error = error.is_a?(Postmark::InactiveRecipientError)
    named_emails = inactive_recipient_error ? normalized(error.recipients) : []
    failed_emails = named_emails.presence || (emails.one? ? emails : [])
    delivered_any = inactive_recipient_error && (emails - failed_emails).any?
    update(delivery_status: delivered_any ? "delivery_partial_success" : "delivery_failure",
      delivery_error: error.class)
    # Postmark refuses a deactivated address itself, so this doesn't block anything -
    # it's recorded to show why the emails stopped arriving
    user_emails_for(failed_emails).each { it.update_last_email_errored!(email_errored: true) }

    raise error unless undeliverable_error?(error.class.name)
  end

  def undeliverable_error?(error_name)
    Notification::UNDELIVERABLE_ERRORS.map(&:name).include?(error_name)
  end

  def normalized_recipient_emails
    normalized(recipient_emails)
  end

  def normalized(emails)
    emails.map { EmailNormalizer.normalize(it) }
  end

  def user_emails_for(emails)
    UserEmail.where(email: emails).to_a
  end
end
