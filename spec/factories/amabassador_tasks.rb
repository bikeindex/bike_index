FactoryBot.define do
  factory :ambassador_task do
    before(:create) do
      AmbassadorTask.skip_callback(:create, :after, :ensure_assigned_to_all_ambassadors!)
    end
    sequence(:title) { |n| "Task ##{n}" }
    sequence(:description) { |n| "Task ##{n} description" }
  end
end
