FactoryBot.define do
  factory :bike_sticker do
    sequence(:code) { |n| "999#{n}" }

    factory :bike_sticker_claimed do
      transient do
        user { FactoryBot.create(:user) }
        bike { FactoryBot.create(:bike) }
      end
      after(:create) do |bike_sticker, evaluator|
        # Have to set these things or previous_bike_id doesn't work correctly,
        # ... because transient doesn't actually work
        bike_claiming = evaluator.bike
        user_claiming = evaluator.user
        bike_sticker.bike_id = nil
        bike_sticker.user_id = nil
        bike_sticker.claim(bike: evaluator.bike, user: evaluator.user)
      end
    end
  end
end
