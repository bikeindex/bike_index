FactoryBot.define do
  factory :ambassador_task do
    sequence(:description) { |n| "Task ##{n}" }
  end
end
