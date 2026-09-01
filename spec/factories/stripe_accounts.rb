FactoryBot.define do
  factory :stripe_account do
    account_holder { FactoryBot.create(:user_confirmed) }
    stripe_id { "acct_#{SecureRandom.hex(8)}" }

    trait :payable do
      charges_enabled { true }
      payouts_enabled { true }
      details_submitted { true }
      onboarded_at { Time.current - 1.day }
    end
  end
end
