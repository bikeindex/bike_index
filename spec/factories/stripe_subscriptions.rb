# == Schema Information
#
# Table name: stripe_subscriptions
#
#  id                     :bigint           not null, primary key
#  end_at                 :datetime
#  referral_source        :text
#  start_at               :datetime
#  stripe_status          :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  membership_id          :bigint
#  stripe_id              :string
#  stripe_price_stripe_id :string
#  user_id                :bigint
#
# Indexes
#
#  index_stripe_subscriptions_on_membership_id           (membership_id)
#  index_stripe_subscriptions_on_stripe_price_stripe_id  (stripe_price_stripe_id)
#  index_stripe_subscriptions_on_user_id                 (user_id)
#
FactoryBot.define do
  factory :stripe_subscription do
    stripe_price { FactoryBot.create(:stripe_price_basic) }
    user { FactoryBot.create(:user_confirmed) }
    membership { FactoryBot.create(:membership, user:, creator: nil) }
    start_at { membership&.start_at || Time.current }

    factory :stripe_subscription_active do
      stripe_status { "active" }
    end
  end
end
