# == Schema Information
#
# Table name: stripe_subscriptions
#
#  id              :bigint           not null, primary key
#  end_at          :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  membership_id   :bigint
#  stripe_price_id :bigint
#
# Indexes
#
#  index_stripe_subscriptions_on_membership_id    (membership_id)
#  index_stripe_subscriptions_on_stripe_price_id  (stripe_price_id)
#
class StripeSubscription < ApplicationRecord
  belongs_to :membership
end
