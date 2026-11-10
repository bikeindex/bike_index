FactoryBot.define do
  factory :education_course_acknowledgment do
    education_course factory: :education_course_active
    owner_email { "owner@example.com" }
    acknowledged_at { Time.current }

    factory :education_course_acknowledgment_pending do
      acknowledged_at { nil }
    end
  end
end
