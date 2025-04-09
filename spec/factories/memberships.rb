FactoryBot.define do
  factory :membership do
    user { FactoryBot.create(:user_confirmed) }
    level { "basic" }
    start_at { Time.current - 1.hour }
    creator { FactoryBot.create(:superuser) }

    trait :with_payment do
      after(:create) do |membership|
        FactoryBot.create(:payment, membership:, user: membership.user)
      end
    end

    factory :membership_stripe_managed do
      creator { nil }

      after(:create) do |membership|
        FactoryBot.create(:stripe_subscription, membership:)
      end
    end
  end
end
