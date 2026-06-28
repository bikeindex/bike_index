FactoryBot.define do
  factory :registration_sequence do
    organization

    trait :with_pages do
      after(:create) do |registration_sequence|
        FactoryBot.create_list(:registration_sequence_page, 2, registration_sequence:)
      end
    end

    factory :registration_sequence_active do
      start_at { Time.current }
    end

    factory :registration_sequence_template do
      organization { nil }
    end
  end
end
