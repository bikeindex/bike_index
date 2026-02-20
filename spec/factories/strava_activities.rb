# frozen_string_literal: true

FactoryBot.define do
  factory :strava_activity do
    strava_integration
    sequence(:strava_id) { |n| "activity_#{n}" }
    title { "Morning Ride" }
    distance_meters { 25000.0 }
    activity_type { "Ride" }
    start_date { Time.current - 1.day }

    trait :enriched do
      enriched_at { Time.current }
    end

    trait :with_location do
      segment_locations { {"cities" => ["San Francisco"], "states" => ["California"], "countries" => ["United States"]} }
    end

    trait :with_gear do
      gear_id { "b1234" }
    end

    trait :with_details do
      with_location
      with_gear
      description { "Great ride through the park" }
      photos { {"photo_url" => "https://example.com/photo.jpg", "photo_count" => 1} }
    end

    trait :run do
      title { "Morning Run" }
      activity_type { "Run" }
      distance_meters { 5000.0 }
    end

    trait :virtual_ride do
      title { "Zwift Session" }
      activity_type { "VirtualRide" }
    end

    trait :mountain_bike_ride do
      title { "Trail Ride" }
      activity_type { "MountainBikeRide" }
    end

    trait :gravel_ride do
      title { "Gravel Grinder" }
      activity_type { "GravelRide" }
    end

    trait :ebike_ride do
      title { "E-Bike Commute" }
      activity_type { "EBikeRide" }
    end
  end
end
