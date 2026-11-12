FactoryBot.define do
  factory :education_course do
    organization

    # Built rather than created, so they save alongside the course - activation
    # freezes the pages, so they have to be there first
    trait :with_pages do
      after(:build) do |education_course|
        2.times do |index|
          education_course.education_course_pages
            .build(title: "Safety check", listing_order: index,
              body: "<ul><li>point one</li><li>point two</li></ul>")
        end
      end
    end

    trait :activated do
      start_at { Time.current }
    end

    factory :education_course_active, traits: [:activated]

    # The default course drafts, activates and archives like an organization's course
    factory :education_course_default do
      organization { nil }

      factory :education_course_default_active, traits: [:activated]
    end
  end
end
