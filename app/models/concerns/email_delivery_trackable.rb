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

  class_methods do
    # Takes the record and a block that delivers its email. Raises the delivery's error,
    # unless the addresses are undeliverable
    def track_email_delivery(record, is_new_email_address: false)
      return if record.delivery_settled?

      recipients = record.recipient_users.to_a
      addresses = normalized(record.recipient_emails)
      # Addresses are held per user, so an address another account also holds is theirs alone
      user_emails = UserEmail.where(user_id: recipients.map(&:id), email: addresses).to_a

      if delivery_email_banned?(record, recipients:, user_emails:, is_new_email_address:)
        return record.update(delivery_status: "delivery_banned")
      end

      # Only the send is rescued - a ban evaluation that blows up hasn't failed to deliver anything
      begin
        handle_delivery_success(record, yield, user_emails:)
      rescue => e
        handle_delivery_error(record, e, addresses:, user_emails:)
      end
    end

    private

    # A ban covers one address, so only a batch that's entirely banned is blocked
    def delivery_email_banned?(record, recipients:, user_emails:, is_new_email_address:)
      return false if record.email_ban_exempt? || recipients.none?

      recipients.all? do |user|
        EmailBan.ban?(user, user_email: user_emails.find { it.user_id == user.id }, is_new_email_address:)
      end
    end

    def handle_delivery_success(record, delivery, user_emails:)
      record.update(delivery_status: "delivery_success",
        message_id: record.message_id || delivery.try(:message_id))
      user_emails.each { it.update_last_email_errored!(email_errored: false) }
      nil
    end

    # Postmark's 406 is a partial delivery - the rest of the batch goes out, whether or not it
    # names who it rejected, and an error it doesn't name can only be pinned on a lone recipient
    def handle_delivery_error(record, error, addresses:, user_emails:)
      inactive_recipient_error = error.is_a?(Postmark::InactiveRecipientError)
      named_emails = inactive_recipient_error ? normalized(error.recipients) : []
      failed_emails = named_emails.presence || (addresses.one? ? addresses : [])
      delivered_any = inactive_recipient_error && (addresses - failed_emails).any?
      record.update(delivery_status: delivered_any ? "delivery_partial_success" : "delivery_failure",
        delivery_error: error.class)
      # Postmark refuses a deactivated address itself, so this doesn't block anything -
      # it's recorded to show why the emails stopped arriving
      user_emails.select { failed_emails.include?(it.email) }
        .each { it.update_last_email_errored!(email_errored: true) }

      raise error unless Notification::UNDELIVERABLE_ERROR_NAMES.include?(error.class.name)
    end

    def normalized(emails)
      emails.map { EmailNormalizer.normalize(it) }
    end
  end

  def email_ban_exempt?
    false
  end

  # A settled delivery isn't worth sending again - it delivered, we blocked it, or its
  # addresses are dead
  def delivery_settled?
    Notification::SETTLED_STATUSES.include?(delivery_status) ||
      Notification::UNDELIVERABLE_ERROR_NAMES.include?(delivery_error)
  end
end
