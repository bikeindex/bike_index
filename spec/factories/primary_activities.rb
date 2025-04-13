FactoryBot.define do
  factory :primary_activity do
    sequence(:name) { |n| "Bike Activity Type #{n}" }
    family { false }

    factory :primary_activity_family do
      family { true }
    end

    trait :with_family do
      primary_activity_family { FactoryBot.create(:primary_activity_family) }
    end

    factory :primary_activity_flavor_with_family, traits: [:with_family]
  end
end
