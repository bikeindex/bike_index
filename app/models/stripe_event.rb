class StripeEvent < ApplicationRecord
  belongs_to :stripe_subscription
end
