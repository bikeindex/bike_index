FactoryBot.define do
  factory :color do
    name { FactoryBot.generate(:unique_name) }
    priority { 1 }
  end
end
