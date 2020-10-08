FactoryBot.define do
  factory :user_phone do
    user { FactoryBot.create(:user) }
    sequence(:phone) { |n| n.to_s.rjust(7, "2") }
  end
end
