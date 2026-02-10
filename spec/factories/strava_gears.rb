# frozen_string_literal: true

FactoryBot.define do
  factory :strava_gear do
    strava_integration
    strava_gear_id { "b12345" }
    strava_gear_name { "My Road Bike" }
    gear_type { "bike" }

    trait :with_bike do
      association :item, factory: :bike
    end

    trait :shoe do
      strava_gear_id { "g12345" }
      strava_gear_name { "Running Shoes" }
      gear_type { "shoe" }
    end
  end
end
