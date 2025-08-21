FactoryBot.define do
  factory :color do
    sequence(:name) { |n| "Color #{n}" }
    priority { 1 }
  end
end
