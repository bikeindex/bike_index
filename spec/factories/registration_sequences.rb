FactoryBot.define do
  factory :registration_sequence do
    organization
    status { :draft }

    trait :with_pages do
      after(:create) do |registration_sequence|
        FactoryBot.create_list(:registration_sequence_page, 2, registration_sequence:)
      end
    end

    factory :registration_sequence_live do
      status { :live }
    end

    factory :registration_sequence_template do
      organization { nil }
      status { :template }
    end
  end
end
