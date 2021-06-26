FactoryBot.define do
  factory :bike_sticker do
    sequence(:code) { |n| "999#{n}" }

    factory :bike_sticker_claimed do
      transient do
        user { FactoryBot.create(:user) }
        bike { FactoryBot.create(:bike) }
      end
      after(:create) do |bike_sticker, evaluator|
        bike_sticker.claim(bike: evaluator.bike, user: evaluator.user)
      end
    end
  end
end
