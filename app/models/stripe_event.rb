# == Schema Information
#
# Table name: stripe_events
# Database name: primary
#
#  id                :bigint           not null, primary key
#  name              :string
#  payload           :jsonb
#  processed_at      :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  stripe_account_id :string
#  stripe_event_id   :string
#  stripe_id         :string
#
# Indexes
#
#  index_stripe_events_on_stripe_event_id  (stripe_event_id) UNIQUE
#
class StripeEvent < ApplicationRecord
  KNOWN_EVENTS = %w[checkout.session.completed customer.subscription.created
    customer.subscription.deleted customer.subscription.updated invoice.payment_failed].freeze

  def self.create_from(event)
    # Stripe redelivers an event until it gets a 2xx, so a retry finds the stored row
    create_with(name: event["type"], stripe_account_id: event["account"], payload: event.to_hash)
      .create_or_find_by!(stripe_event_id: event["id"])
  end

  def test?
    false
  end

  def live?
    !test?
  end

  def known_event?
    KNOWN_EVENTS.include?(name)
  end

  def checkout?
    name.match(/checkout/)
  end

  def subscription?
    name.match(/subscription/)
  end
end
