FactoryBot.define do
  factory :bike_sticker_batch do
    user { FactoryBot.create(:admin) }
    sequence(:prefix) { |n| "G#{n}" }
  end
end
