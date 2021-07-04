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
        # ... because transient doesn't skip assigning the attributes if they exist.
        # NOTE: passing bike_id or user_id (rather than bike/user) doesn't work correctly
        bike_claiming = evaluator.bike || bike_sticker.bike
        user_claiming = evaluator.user || bike_sticker.user
        bike_sticker.bike_id = nil
        bike_sticker.user_id = nil
        bike_sticker.claim(bike: bike_claiming, user: user_claiming)
      end
    end
  end
end
