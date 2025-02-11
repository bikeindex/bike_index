FactoryBot.define do
  factory :stripe_subscription do
    membership { FactoryBot.create(:membership) }
    start_at { Time.current - 1.minute }
  end
end
