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

  attr_accessor :data

  def self.create_from(event)
    data = event["data"]

    # Stripe redelivers an event until it gets a 2xx, so a retry finds the stored row
    stripe_event = create_with(name: event["type"], stripe_id: data["object"]["id"],
      stripe_account_id: event["account"], payload: event.to_hash)
      .create_or_find_by!(stripe_event_id: event["id"])
    stripe_event.data = data
    stripe_event
  end

  def test?
    false
  end

  def live?
    !test?
  end

  def data_object
    data["object"]
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

  def update_bike_index_record!
    # Currently, only handle on creation, when the data object is assigned.
    raise "Stripe Data not assigned, unable to handle" unless @data.present?
    # Stripe can redeliver a processed event. A subscription event carries the subscription as
    # it was then, so a redelivery could undo a later event. Out of order first deliveries
    # still apply as they arrive
    return if processed_at.present?

    if checkout?
      if data_object.subscription.present?
        update_stripe_subscription(Stripe::Subscription.retrieve(data_object.subscription), data_object)
      end
    elsif subscription?
      update_stripe_subscription(data_object)
    end
    update!(processed_at: Time.current)
  end

  private

  def update_stripe_subscription(stripe_subscription_obj, stripe_checkout_session = nil)
    StripeSubscription.create_or_update_from_stripe!(stripe_subscription_obj:, stripe_checkout_session:)
  end
end
