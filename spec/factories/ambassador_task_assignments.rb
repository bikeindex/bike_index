FactoryBot.define do
  factory :ambassador_task_assignment do
    user { FactoryBot.create(:ambassador) }
    ambassador_task { FactoryBot.create(:ambassador_task) }
    trait :completed do
      completed_at { Time.current }
    end
  end
end
