# == Schema Information
#
# Table name: stripe_events
#
#  id                            :bigint           not null, primary key
#  name                          :string
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  stripe_subscription_stripe_id :string
#
# Indexes
#
#  index_stripe_events_on_stripe_subscription_stripe_id  (stripe_subscription_stripe_id)
#
class StripeEvent < ApplicationRecord
  belongs_to :stripe_subscription
end
