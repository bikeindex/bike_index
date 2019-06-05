FactoryBot.define do
  factory :ambassador_task_assignment do
    ambassador { FactoryBot.create(:ambassador) }
    ambassador_task { FactoryBot.create(:ambassador_task) }

    trait :completed do
      completed_at { Time.current }
    end

    trait :completed_an_hour_ago do
      completed_at { Time.current - 1.hour }
    end

    trait :completed_a_day_ago do
      completed_at { Time.current - 1.day }
    end
  end
end
