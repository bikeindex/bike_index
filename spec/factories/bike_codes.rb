FactoryBot.define do
  factory :bike_code do
    sequence(:code) { |n| "999#{n}" }
    factory :bike_code_claimed do
      claimed_at { Time.now }
      user { FactoryBot.create(:user) }
      bike { FactoryBot.create(:bike) }
    end
  end
end
