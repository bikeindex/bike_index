FactoryBot.define do
  factory :ambassador_task do
    before(:create) do
      AmbassadorTask.skip_callback(:create, :after, :ensure_assigned_to_all_ambassadors!)
    end
    after(:create) do
      AmbassadorTask.set_callback(:create, :after, :ensure_assigned_to_all_ambassadors!)
    end
    sequence(:title) { |n| "Task ##{n.to_s.rjust(3, "0")}" }
    sequence(:description) { |n| "Task ##{n.to_s.rjust(3, "0")} description" }
  end
end
