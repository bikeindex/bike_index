FactoryBot.define do
  factory :bike_code_batch do
    user { FactoryBot.create(:admin) }
  end
end
