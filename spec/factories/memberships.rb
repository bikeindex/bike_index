FactoryBot.define do
  factory :membership do
    user { FactoryBot.create(:user_confirmed) }
    kind { "basic" }
    start_at { Time.current - 1.hour }
    creator { FactoryBot.create(:admin) }

    factory :membership_stripe_managed do
      creator { nil }

      after(:create) do |membership|
        FactoryBot.create(:stripe_subscription, membership:)
      end
    end
  end
end
