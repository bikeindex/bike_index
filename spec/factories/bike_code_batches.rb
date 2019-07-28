FactoryBot.define do
  factory :bike_code_batch do
    user { FactoryBot.create(:admin) }
    sequence(:prefix) { |n| "G#{n}" }
  end
end
