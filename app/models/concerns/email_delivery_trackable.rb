# frozen_string_literal: true

# For records that own an email's delivery_status - Notifications::Deliver writes it
module EmailDeliveryTrackable
  extend ActiveSupport::Concern

  included do
    scope :delivered, -> { where(delivery_status: Notification::DELIVERED_STATUSES) }
    # A send we blocked is as undelivered as one postmark refused
    scope :delivery_failed, -> { where(delivery_status: %w[delivery_failure delivery_banned]) }
    # Must match settled?
    scope :settled, -> {
      where(delivery_status: Notification::SETTLED_STATUSES)
        .or(where(delivery_error: Notification::UNDELIVERABLE_ERROR_NAMES))
    }
  end

  def email_ban_exempt?
    false
  end

  # A settled delivery isn't worth sending again
  def settled?
    Notification::SETTLED_STATUSES.include?(delivery_status) ||
      Notification::UNDELIVERABLE_ERROR_NAMES.include?(delivery_error)
  end
end
