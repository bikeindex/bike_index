FactoryBot.define do
  factory :bike_sticker do
    sequence(:code) { |n| "999#{n}" }

    factory :bike_sticker_claimed do
      claimed_at { Time.current }
      user { FactoryBot.create(:user) }
      bike { FactoryBot.create(:bike) }
    end
  end
end
