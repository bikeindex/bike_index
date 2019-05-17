FactoryBot.define do
  factory :ambassador_task do
    sequence(:title) { |n| "Task ##{n}" }
    sequence(:description) { |n| "Task ##{n} description" }
  end
end
