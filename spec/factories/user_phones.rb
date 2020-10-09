FactoryBot.define do
  factory :user_phone do
    user { FactoryBot.create(:user) }
    sequence(:phone) { |n| n.to_s.rjust(7, "2") }
    factory :user_phone_confirmed do
      confirmed_at { Time.current - 1.minutes }
    end
  end
end
