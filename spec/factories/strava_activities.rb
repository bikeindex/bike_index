# frozen_string_literal: true

FactoryBot.define do
  factory :strava_activity do
    strava_integration
    sequence(:strava_id) { |n| "activity_#{n}" }
    title { "Morning Ride" }
    distance { 25000.0 }
    year { 2025 }
    activity_type { "Ride" }
    start_date { Time.current - 1.day }

    trait :with_location do
      start_latitude { 37.7749 }
      start_longitude { -122.4194 }
      location_city { "San Francisco" }
      location_state { "California" }
      location_country { "United States" }
    end

    trait :with_gear do
      gear_id { "b1234" }
      gear_name { "My Road Bike" }
    end

    trait :with_details do
      with_location
      with_gear
      description { "Great ride through the park" }
      photos { [{"id" => "photo_123", "urls" => {"600" => "https://example.com/photo.jpg"}}] }
    end

    trait :run do
      title { "Morning Run" }
      activity_type { "Run" }
      distance { 5000.0 }
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
