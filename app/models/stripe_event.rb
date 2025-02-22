# == Schema Information
#
# Table name: stripe_events
#
#  id         :bigint           not null, primary key
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  stripe_id  :string
#
class StripeEvent < ApplicationRecord
  KNOWN_EVENTS = %w[checkout.session.completed customer.subscription.created
    customer.subscription.deleted customer.subscription.updated invoice.payment_failed].freeze

  attr_accessor :data

  def self.create_from(event)
    data = event["data"]

    stripe_event = create(name: event["type"], stripe_id: data["object"]["id"])
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

  def update_bike_index_record
    # Currently, only handle on creation, when the data object is assigned.
    raise "Stripe Data not assigned, unable to handle" unless @data.present?

    if checkout?
      if data_object.subscription.present?
        update_stripe_subscription(Stripe::Subscription.retrieve(data_object.subscription), data_object)
      end
    elsif subscription?
      update_stripe_subscription(data_object)
    end
  end

  private

  def update_stripe_subscription(stripe_subscription_obj, stripe_checkout_session = nil)
    StripeSubscription.create_or_update_from_stripe!(stripe_subscription_obj:, stripe_checkout_session:)
  end
end
