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
