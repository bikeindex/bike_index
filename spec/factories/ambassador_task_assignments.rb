FactoryBot.define do
  factory :ambassador_task_assignment do
    transient do
      organization { FactoryBot.create(:organization_ambassador) }
    end

    ambassador { FactoryBot.create(:ambassador, organization: organization) }
    ambassador_task { FactoryBot.create(:ambassador_task) }

    trait :completed do
      completed_at { Time.current }
    end

    trait :completed_an_hour_ago do
      completed_at { 1.hour.ago }
    end

    trait :completed_a_day_ago do
      completed_at { 1.day.ago }
    end
  end
end
