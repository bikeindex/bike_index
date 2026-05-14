# frozen_string_literal: true

module EmailDeliveryTrackable
  extend ActiveSupport::Concern

  UNDELIVERABLE_ERRORS = %w[Postmark::InactiveRecipientError Postmark::InvalidEmailAddressError].freeze

  # The block performs an email delivery (e.g. SomeMailer.foo.deliver_now).
  # Records success/failure on self, and re-raises non-undeliverable errors.
  def track_email_delivery
    return if delivery_success?

    delivery = yield

    record_email_delivery_success(delivery)
  rescue => e
    record_email_delivery_failure(e)

    raise e unless UNDELIVERABLE_ERRORS.include?(e.class.name)
  end
end
