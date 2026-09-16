module Notifications
  # Delivers an email for a record that owns a delivery_status, listing who it emails in
  # recipient_users and recipient_emails
  module Deliver
    extend Functionable

    # Raises the delivery's error, unless the addresses are undeliverable
    def track_email(record, is_new_email_address: false)
      return if record.settled?

      recipients = record.recipient_users.to_a
      addresses = normalized(record.recipient_emails)
      # Addresses are held per user, so an address another account also holds is theirs alone
      user_emails = recipients.any? ? UserEmail.where(user_id: recipients.map(&:id), email: addresses).to_a : []

      if delivery_email_banned?(record, recipients:, user_emails:, is_new_email_address:)
        return record.update(delivery_status: "delivery_banned")
      end

      # Only the send is rescued - a ban evaluation that blows up hasn't failed to deliver anything
      begin
        delivery = yield
        record.update(delivery_status: "delivery_success",
          message_id: record.message_id || delivery.try(:message_id))
        user_emails.each { it.update_last_email_errored!(email_errored: false) }
        nil
      rescue => e
        handle_delivery_error(record, e, addresses:, user_emails:)
      end
    end

    #
    # private below here
    #

    # A ban covers one address, so only a batch that's entirely banned is blocked
    def delivery_email_banned?(record, recipients:, user_emails:, is_new_email_address:)
      return false if record.email_ban_exempt? || recipients.none?

      recipients.all? do |user|
        EmailBan.ban?(user, user_email: user_emails.find { it.user_id == user.id }, is_new_email_address:)
      end
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

    conceal :delivery_email_banned?, :handle_delivery_error, :normalized
  end
end
