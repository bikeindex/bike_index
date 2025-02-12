FactoryBot.define do
  factory :stripe_subscription do
    user { FactoryBot.create(:user_confirmed) }
    membership { FactoryBot.create(:membership, user:) }
    start_at { Time.current - 1.minute }
  end
end
