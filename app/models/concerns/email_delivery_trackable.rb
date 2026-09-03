# frozen_string_literal: true

# For records that own an email's delivery_status. Wrap the delivery in
# track_email_delivery; the record says what to store via record_delivery_success
# and record_delivery_failure
module EmailDeliveryTrackable
  extend ActiveSupport::Concern

  UNDELIVERABLE_ERRORS = [Postmark::InactiveRecipientError, Postmark::InvalidEmailRequestError].freeze

  # This method takes a block
  def track_email_delivery
    return if delivery_success?

    delivery = yield
    record_delivery_success(delivery)
  rescue => e
    record_delivery_failure(e)

    raise e unless UNDELIVERABLE_ERRORS.any? { |error_class| e.is_a?(error_class) }
  end

  private

  # Postmark names the addresses it rejected as inactive, and delivers to the rest of
  # the batch. Any other error leaves no way to tell who received the email
  def inactive_recipient_emails(error)
    return [] unless error.is_a?(Postmark::InactiveRecipientError)

    error.recipients.map { EmailNormalizer.normalize(it) }
  end
end
