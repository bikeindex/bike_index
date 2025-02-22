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
    data = event['data']
    stripe_event = create(name: event['type'], stripe_id: data["object"]["id"])
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
    data["object"] || {}
  end

  def known_event?
    KNOWN_EVENTS.include?(name)
  end

  def checkout_id?
    name.match(/checkout/)
  end

  def subscription_id?
    name.match(/subscription/)
  end

  def stripe_subscription
    if checkout_id?
      StripeSubscription.find_or_create_from_stripe(stripe_checkout: data_object)
    elsif subscription_id?
      # StripeSubscription.find_or_create_from_stripe(stripe_subscription_obj: data_object)
    end
  end
end
