# == Schema Information
#
# Table name: ambassador_task_assignments
#
#  id                 :integer          not null, primary key
#  completed_at       :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  ambassador_task_id :integer          not null
#  user_id            :integer          not null
#
# Indexes
#
#  index_ambassador_task_assignments_on_ambassador_task_id  (ambassador_task_id)
#  unique_assignment_to_ambassador                          (user_id,ambassador_task_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (ambassador_task_id => ambassador_tasks.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
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
      completed_at { Time.current - 1.hour }
    end

    trait :completed_a_day_ago do
      completed_at { Time.current - 1.day }
    end
  end
end
